Nextcloud Tips
================

Q: How to remove reset password link?

Set the "lost_password_link" to "disabled" as

```
docker exec -it -u www-data homecloud_nextcloudapp php occ config:system:set lost_password_link --value="disabled"
```

Q: Set the default_phone_region?

```
docker exec -it -u www-data homecloud_nextcloudapp php occ config:system:set default_phone_region --value="SG"
```

This sets the default region for phone numbers on your Nextcloud server, using ISO 3166-1 country codes such as DE for Germany, FR for France, … It is required to allow inserting phone numbers in the user profiles starting without the country code (e.g. +49 for Germany).
