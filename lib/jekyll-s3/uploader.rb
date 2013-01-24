require 'tempfile'
require 'zlib'

module Jekyll
  module S3
    class Uploader
      def self.run(site_dir, config, in_headless_mode = false)
        puts "Deploying _site/* to #{config['s3_bucket']}"

        s3 = AWS::S3.new(:access_key_id => config['s3_id'],
                         :secret_access_key => config['s3_secret'],
                         :s3_endpoint => Endpoint.new(config['s3_endpoint']).hostname )

        new_files_count, changed_files_count, changed_files = upload_files(
          s3, config, site_dir
        )

        deleted_files_count = remove_superfluous_files(
          s3, config['s3_bucket'], site_dir, in_headless_mode)

        print_done_report config

        [new_files_count, changed_files_count, deleted_files_count, changed_files]
      end

      private

      def self.print_done_report(config)
        bucket_name = config['s3_bucket']
        website_hostname_suffix = Endpoint.new(config['s3_endpoint']).website_hostname
        website_hostname_with_bucket =
          "%s.%s" % [bucket_name, website_hostname_suffix]
        puts "Done! Go visit: http://#{website_hostname_with_bucket}/index.html"
      end

      def self.upload_files(s3, config, site_dir)
        changed_files, new_files = DiffHelper.resolve_files_to_upload(
          s3.buckets[config['s3_bucket']], site_dir)
        to_upload = changed_files + new_files
        if to_upload.empty?
          puts "No new or changed files to upload"
        else
          pre_upload_report = []
          pre_upload_report << "Uploading"
          pre_upload_report << "#{new_files.length} new" if new_files.length > 0
          pre_upload_report << "and" if changed_files.length > 0 and new_files.length > 0
          pre_upload_report << "#{changed_files.length} changed" if changed_files.length > 0
          pre_upload_report << "file(s)"
          puts pre_upload_report.join(' ')
          to_upload.each do |f|
            upload_file(f, s3, config, site_dir)
          end
        end
        [new_files.length, changed_files.length, changed_files]
      end

      def self.upload_file(file, s3, config, site_dir)
        Retry.run_with_retry do
          mime_type = MIME::Types.type_for(file)
          metadata = {
            :content_type => mime_type.first,
            :reduced_redundancy => config['s3_reduced_redundancy']
          }
          
          s3_object = s3.buckets[config['s3_bucket']].objects[file]
          local_filename = "#{site_dir}/#{file}"
          gzip = (config['gzip_extensions'] || [".html", ".css", ".js", ".svg", ".txt"]).include?(File.extname file)
          
          upload_succeeded = if gzip
            Tempfile.open(File.basename(file)) do |tempfile|
              metadata[:content_encoding] = "gzip"
              
              gz = Zlib::GzipWriter.new(tempfile, Zlib::BEST_COMPRESSION, Zlib::DEFAULT_STRATEGY)
              gz.mtime = File.mtime(local_filename)
              gz.orig_name = File.basename(file)
              File.open(local_filename) do |f|
                IO.copy_stream(f, gz)
              end                
              gz.flush
              
              tempfile.flush
              tempfile.rewind
              s3_object.write(tempfile, metadata)
              gz.close
            end
          else
            File.open(local_filename) do |f|
              s3_object.write(f, metadata)
            end
          end
          
          if upload_succeeded
            puts("Upload #{file}#{gzip ? " (gzipped)" : ""}: Success!")
          else
            puts("Upload #{file}#{gzip ? " (gzipped)" : ""}: FAILURE!")
          end
        end
      end

      def self.remove_superfluous_files(s3, s3_bucket_name, site_dir, in_headless_mode)
        remote_files = s3.buckets[s3_bucket_name].objects.map { |f| f.key }
        local_files = load_all_local_files(site_dir)
        files_to_delete = remote_files - local_files
        deleted_files_count = 0
        if in_headless_mode
          files_to_delete.each { |s3_object_key|
            delete_s3_object s3, s3_bucket_name, s3_object_key
            deleted_files_count += 1
          }
        else
          Keyboard.if_user_confirms_delete(files_to_delete) { |s3_object_key|
            delete_s3_object s3, s3_bucket_name, s3_object_key
            deleted_files_count += 1
          }
        end
        deleted_files_count
      end

      def self.delete_s3_object(s3, s3_bucket_name, s3_object_key)
        Retry.run_with_retry do
          s3.buckets[s3_bucket_name].objects[s3_object_key].delete
          puts("Delete #{s3_object_key}: Success!")
        end
      end

      def self.load_all_local_files(site_dir)
        Dir[site_dir + '/**/{*,.*}'].
          delete_if { |f| File.directory?(f) }.
          map { |f| f.gsub(site_dir + '/', '') }
      end
    end
  end
end
