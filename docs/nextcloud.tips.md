Nextcloud Tips
================

Q: How to remove reset password link?

Set the "lost_password_link" to "disabled" as

```
docker exec -it -u www-data homecloud_nextcloudapp php occ config:system:set lost_password_link --value="disabled"
```
