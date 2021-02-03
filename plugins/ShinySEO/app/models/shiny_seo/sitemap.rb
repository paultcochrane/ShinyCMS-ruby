# frozen_string_literal: true

# ShinySEO plugin for ShinyCMS ~ https://shinycms.org
#
# Copyright 2009-2021 Denny de la Haye ~ https://denny.me
#
# ShinyCMS is free software; you can redistribute it and/or modify it under the terms of the GPL (version 2 or later)

module ShinySEO
  # A thin wrapper around the sitemap_generator gem - part of the ShinySEO plugin for ShinyCMS
  class Sitemap
    include ShinyS3
    include ShinySiteURL

    include Rails.application.routes.url_helpers

    def initialize
      SitemapGenerator::Sitemap.default_host = site_base_url

      use_aws_sdk_adapter_if_configured
    end

    def generate
      SitemapGenerator::Sitemap.create do
        ShinyPlugin.models_with_sitemap_items.each do |model|
          model.sitemap_items.each do |resource|
            item = ShinySEO::SitemapItem.new resource

            add item.path, lastmod: item.content_updated_at, changefreq: item.update_frequency
          end
        end
      end
    end

    private

    def use_aws_sdk_adapter_if_configured
      return unless aws_s3_feeds_config_present?

      require 'aws-sdk-s3'

      SitemapGenerator::Sitemap.adapter = SitemapGenerator::AwsSdkAdapter.new(
        's3_bucket',
        aws_secret_access_key: aws_s3_feeds_secret_access_key,
        aws_access_key_id:     aws_s3_feeds_access_key_id,
        aws_region:            aws_s3_feeds_region,
        aws_endpoint:          aws_s3_feeds_endpoint
      )
    end
  end
end
