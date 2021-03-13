# frozen_string_literal: true

# ShinyCMS ~ https://shinycms.org
#
# Copyright 2009-2021 Denny de la Haye ~ https://denny.me
#
# ShinyCMS is free software; you can redistribute it and/or modify it under the terms of the GPL (version 2 or later)

require 'rails_helper'

# Tests for the discussion mailer (comment/content reply notifications)
RSpec.describe ShinyCMS::DiscussionMailer, type: :mailer do
  before do
    ShinyCMS::FeatureFlag.enable :comment_notifications
  end

  let( :discussion ) { create :discussion, resource: ( create :blog_post )          }
  let( :site_name  ) { ShinyCMS::Setting.get( :site_name ) || I18n.t( 'site_name' ) }

  describe '.parent_comment_author_notification' do
    context 'when the parent comment author was an authenticated user' do
      it 'generates an email to them' do
        user  = create :user
        top   = create :top_level_comment, discussion: discussion, author: user
        reply = create :nested_comment, parent: top, discussion: discussion

        email = described_class.with( comment: reply ).parent_comment_author_notification

        subject = I18n.t(
          'shinycms.discussion_mailer.parent_comment_author_notification.subject',
          comment_author_name: reply.author.name,
          site_name:           site_name
        )

        expect( email.subject ).to eq subject
      end
    end

    context 'when the parent comment author was a pseudonymous user with an email address' do
      it 'generates an email to them' do
        recipient = create :email_recipient, :confirmed
        author = create :pseudonymous_author, name: recipient.name, email_recipient: recipient
        top = create :top_level_comment, discussion: discussion, author: author

        reply = create :nested_comment, parent: top, discussion: discussion

        email = described_class.with( comment: reply ).parent_comment_author_notification

        subject = I18n.t(
          'shinycms.discussion_mailer.parent_comment_author_notification.subject',
          comment_author_name: reply.author.name,
          site_name:           site_name
        )

        expect( email.subject ).to eq subject
      end
    end

    context 'when the parent comment author was a pseudonymous user without an email address' do
      it 'does not generate an email to them' do
        author = create :pseudonymous_author
        top = create :top_level_comment, discussion: discussion, author: author

        reply = create :nested_comment, parent: top, discussion: discussion

        email = described_class.with( comment: reply ).parent_comment_author_notification

        # (email is a NullMail object here, inside some sort of delivery wrapper)
        expect( email.subject ).to be_blank
        expect( email.body    ).to be_blank
      end
    end

    context 'when the parent comment author was an anonymous user' do
      it 'does not generate an email to them' do
        top = create :top_level_comment, discussion: discussion

        reply = create :nested_comment, parent: top, discussion: discussion

        email = described_class.with( comment: reply ).parent_comment_author_notification

        expect( email.subject ).to be_blank  # NullMail object, as above
        expect( email.body    ).to be_blank
      end
    end
  end

  describe '.content_author_notification' do
    it 'generates email to author/owner of content that the discussion is attached to' do
      comment = create :top_level_comment, discussion: discussion

      email = described_class.with( comment: comment ).content_author_notification

      subject = I18n.t(
        'shinycms.discussion_mailer.content_author_notification.subject',
        comment_author_name: comment.author.name,
        content_type:        I18n.t( 'shinycms.models.names.shiny_blog_post' ),
        site_name:           site_name
      )

      expect( email.subject ).to eq subject
    end
  end

  describe '.comment_admin_notification' do
    it 'generates notification email to comment admin address' do
      comment = create :top_level_comment, discussion: discussion

      ShinyCMS::Setting.set :all_comment_notifications_email, to: ShinyCMS::User.first.email

      email = described_class.with( comment: comment ).comment_admin_notification

      subject = I18n.t(
        'shinycms.discussion_mailer.comment_admin_notification.subject',
        comment_author_name: comment.author.name,
        site_name:           site_name
      )

      expect( email.subject ).to eq subject
    end
  end
end
