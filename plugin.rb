
# name: email-extraction
# about: Extract and invite CC'd users to topic
# version: 0.1
# authors: Jordan Seanor
# url: https://github.com/HMSAB/discourse-email-extraction.git


enabled_site_setting :email_extraction_enabled

after_initialize do

  class ::ExtractionHandler

    # Create or extract existing users.
    def self.create_or_find_users(emails, op_id)
      @users = []
      if emails.size > 0
        emails.each do |address|
          if address != SiteSetting.pop3_polling_username
            user = User.find_by_email(address)
            if user.nil? && SiteSetting.enable_staged_users
              begin
                if SiteSetting.email_extraction_create_full_user
                  random_password = Array.new(15){[*"A".."Z", *"0".."9", *"!".."?"].sample}.join
                  puts random_password
                  user = User.create(
                    email: address,
                    username: ::ExtractionHandler.generate_random_user(),
                    name: User.suggest_name(address),
                    password: random_password
                  )
                  user.approve(Discourse.system_user, true)
                  user.activate
                else
                  user = User.create!(
                    email: address,
                    username: ::ExtractionHandler.generate_random_user(),
                    name: User.suggest_name(address),
                    staged: true
                  )
                end
              rescue Exception => e
                puts e.message
                puts e.backtrace.inspect
                user = nil
              end
            end
          end
          @users << user
        end
      end
      @users
    end

    #Generate a random username
    def self.generate_random_user()
      name = SiteSetting.email_extraction_username_prepend + 10.times.map{rand(10)}.join.to_s
      name
    end

    # Extract and invite new email users
    def self.extract_email_details(entry)
      if !entry.raw_email.empty?
        @mail = Mail.new(entry.raw_email)
        @to_users = ::ExtractionHandler.create_or_find_users(@mail.to&.map(&:downcase), entry.user_id)
        @cc_users = ::ExtractionHandler.create_or_find_users(@mail.cc&.map(&:downcase), entry.user_id)
        max_users = 0
        @cc_users.each do |user|
          if max_users < SiteSetting.email_extraction_max_users
            entry.topic.topic_allowed_users.create!(user_id: user.id)
            TopicUser.auto_notification_for_staging(user.id, entry.topic_id, TopicUser.notification_reasons[:auto_watch])
            entry.topic.add_small_action(Discourse.system_user, "invited_user", user.username)
            max_users += 1
          end
        end
      end
    end


    def self.extract_allowed?(entry)
      SiteSetting.email_extraction_enabled
    end
  end

  DiscourseEvent.on(:post_created || :topic_created) do |entry|
    if entry.via_email
      if ::ExtractionHandler.extract_allowed?(entry)
        ::ExtractionHandler.extract_email_details(entry)
      end
    end
  end
end
