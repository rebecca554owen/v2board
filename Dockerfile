# 第一阶段：构建composer依赖
FROM composer AS composer
# 复制配置文件
COPY database/ /app/database/
COPY composer.json /app/
# 安装PHP依赖包
RUN set -x ; cd /app \
      && composer install \
           --ignore-platform-reqs \
           --no-interaction \
           --no-plugins \
           --no-scripts \
           --prefer-dist

# 第二阶段：构建最终镜像
FROM php:8.1-fpm-alpine AS final
# 设置时区
ENV TZ=Asia/Shanghai
# 安装依赖包
RUN apk add autoconf caddy git g++ make openssl-dev supervisor tzdata \
    && ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
# 安装PHP扩展
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && docker-php-ext-install bcmath fileinfo mysqli pcntl pdo_mysql sockets \
    && pecl install redis \
    && docker-php-ext-enable redis

# 工作目录
WORKDIR /www
# 复制配置文件
COPY .docker /
# 复制项目文件
COPY . /www
# 从composer阶段复制vendor目录
COPY --from=composer /app/vendor/ /www/vendor/
# 设置权限
RUN adduser -D -u 1000 -g www www \
    && php artisan storage:link \
    && cp /www/.env.example /www/.env \
    && chown -R www:www /www \
    && chmod -R 775 /www

# 暴露端口 (同时暴露9000和8000)
EXPOSE 9000 8000

# 启动命令
CMD ["/usr/bin/supervisord", "--nodaemon", "-c", "/etc/supervisor/supervisord.conf"]
