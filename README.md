Docker :heart: Magento 2
========================

[![Docker Images List](https://img.shields.io/badge/DockerHub-Dockgento-orange.svg?logo=Docker&style=flat-square)](https://hub.docker.com/r/fauzie/magetwo)
[![Docker Image Size (latest)](https://img.shields.io/docker/image-size/fauzie/magetwo/latest?style=flat-square)](https://hub.docker.com/r/fauzie/magetwo/tags)

Docker image for Magento 2 any version, add your own magento directory with volume mapping. This image will not install your magento, volume mapping to `/magento/website` is required with separated database container.

- Nginx with php-fpm 8.1
- PHP composer ready
- User & group name `magento`
- Home directory `/magento`
- Magento root directory `/magento/website`
- Ready to use default magento cron
- Ready to use redis as session or cache backend

See all available environment variable on **Dockerfile**.

---

Created by [fauzie](https://github.com/fauzie) with :heart: and :coffee:
