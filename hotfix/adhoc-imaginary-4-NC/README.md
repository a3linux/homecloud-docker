The AdHoc patch / hotfix for Nextcloud 25 Priview with Apple HEIC File
=======================================================================

The patched file,

```
<nextcloud-app-path>/lib/private/Preview/Imaginary.php
```

nextcloud-app-path is mostly the /var/www/html inside Nextcloud Docker container.

This patch should be in PR https://github.com/nextcloud/server/pull/37155/files
Should be released in Nextcloud 26 or 25.0.5(backport)
