Docker :heart: Magento 2
========================

Docker image for Magento 2 any version, add your own magento directory with volume mapping. This image will not install your magento, volume mapping to `/magento/website` is required with separated database container.

- Nginx with php-fpm 7.4
- PHP composer ready
- User & group name `magento`
- Home directory `/magento`
- Magento root directory `/magento/website`
- Ready to use default magento cron
- Ready to use redis as session or cache backend

See all available environment variable on **Dockerfile**.

---

Created by [fauzie](https://github.com/fauzie) with :heart: and :coffee:
