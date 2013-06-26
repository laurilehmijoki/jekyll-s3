# jekyll-s3

Dear everyone

The development of jekyll-s3 has moved to
[s3_website](https://github.com/laurilehmijoki/s3_website). It's a fork of
jekyll-s3, and it contains the same features.

In addition to Jekyll users, the gem s3_website attempts to serve users who use
other static website generators. For example, s3_website supports Nanoc.

## For current jekyll-s3 users

### Migrating from jekyll-s3 to s3_website

If you are an existing jekyll-s3 user, here's how you can migrate to s3_website:

1. Install the gem with `gem install s3_website`
2. Rename the file `_jekyll_s3.yml` to `s3_website.yml`
3. Use the command `s3_website push` to deploy your website to S3. This does the
   same thing as calling `jekyll-s3` does.

You don't have to change anything in the configuration file.

#### Backward incompatible changes

If you have been using jekyll-s3 as a library, you need to adjust your API calls
a little bit. The logic is the same. See the README of s3_website for more info.

Also the `-h` as in headless is no longer available; `--headless` still works.

### Want to stick to jekyll-s3?

That's fine. The codebase and documentation are here:
<https://github.com/laurilehmijoki/jekyll-s3/tree/master/>. All the existing
versions are of course available on RubyGems, and they will be.

However, please take into account that I'm planning to incorporate all the new
features into s3_website instead of jekyll-s3. If you are considering to send a
pull request for jekyll-s3, please fork s3_website instead, and send the pull
request there.

Regards
Lauri
