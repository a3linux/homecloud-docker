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

Q: How to scan or re-scan user's files?

This command will scan all user's files,
```
docker exec -it -u www-data homecloud_nextcloudapp php occ files:scan user_id
```

Q: How to do the groupfolder files scan?

This command scan the full groupfolder, please be noticed, groupfolder named as index, 1, 2, 3 ...

```
docker exec -it -u www-data homecloud_nextcloudapp php occ groupfolder:scan <idx>/<sub-folder>
```

Q: Nextcloud Mail App load email slow?

This is discussed a little on Nextcloud forum, as [this thread](https://help.nextcloud.com/t/mail-app-email-loading-slow/109993/8)

Try to run, it might be helpful

```
docker exec -it -u www-data homecloud_nextcloudapp php occ maintenance:mimetype:update-db
docker exec -it -u www-data homecloud_nextcloudapp php occ maintenance:mimetype:update-js
```

Q: How to disable the auto generated contacts call "Recently Contacted" in Contacts app? 
This is more like a Groupware function introduced by Nextcloud Groupware Bundle apps. According to the discussion [here](https://community.e.foundation/t/delete-recently-contacted/38555/3), disable the Nextcloud App contactsinteraction can disable the "Recently Contacted" in Contacts display.

There is no very careful or detail document about this yet.

```
docker exec -it -u www-data homecloud_nextcloudapp php /var/www/html/occ app:disable contactsinteraction
```

Q: Nextcloud preview halt the server with large amount of photos?

Those Nextcloud preview generator app tuning might be helpful and improving the performance, but still very danger for huge amount of photos.

```
occ config:app:set previewgenerator squareSizes --value="32 64 512"
occ config:app:set previewgenerator widthSizes  --value="64 128 512"
occ config:app:set previewgenerator heightSizes --value="64 256 512"
occ config:system:set preview_max_x --value 512
occ config:system:set preview_max_y --value 512
occ config:system:set jpeg_quality --value 60
occ config:app:set preview jpeg_quality --value="60"
```

Q: How to reset all generated preview

WARNING: This is not supported but it has been confirmed to work by multiple users. Proceed at your own risk. Always keep backups around.

1. Remove the folder **your-nextcloud-data-directory/appdata_xxxxxxxx/preview**
2. Optional: change parameters preview_max_x and preview_max_y in config.php (e.g., to 512), and change the previewgenerator app parameters heightSizes, squareSizes and widthSizes as per the README (or better yet, to a low value each, e.g. 512, 256 and 512 respectively)
3. Run, this will reset generated previews in the database
```
occ files:scan-app-data 
```
4. Run, this will run very fast if you did step 2
```
occ preview:generate-all [user-id]
```

Q: Move Nextcloud appdata_xxxx folder to a separate location from Nextcloud data folder

This is not official supported now, but there are lot of discussions online and practices from community.
The simple way is to move the location of appdata folder to a separate one and use the symbol link in Nextcloud data folder.
