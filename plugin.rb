# name: email-extraction
# about: Extract and invite CC'd users to topic
# version: 0.1
# authors: Jordan Seanor
# url: https://github.com/HMSAB/discourse-email-extraction.git

require_relative 'new_user_extraction_email'

enabled_site_setting :email_extraction_enabled

after_initialize do

  class ::ExtractionHandler

    # Create or extract existing users. If  you have
    # not opted to create a full user, instead create
    # a staged user.
    def self.create_or_find_users(emails, topic_id)
      @users = []
      max_users = 0
      if !emails.nil? && emails.size > 0
        emails.each do |address|
        if max_users < SiteSetting.email_extraction_max_users && SiteSetting.email_extraction_should_invite
          if address != SiteSetting.pop3_polling_username
            user = User.find_by_email(address)
            if user.nil? && SiteSetting.enable_staged_users
              begin
                if SiteSetting.email_extraction_create_full_user
                  while true
                    random_password = Array.new(15){[*"A".."Z", *"0".."9"].sample}.join
                    username = ::ExtractionHandler.generate_random_user()
                    if !User.find_by_username(username) # Ensure we don't get a duplicate username.
                      break;
                    end
                  end
                  user = User.create(
                    email: address,
                    username: username,
                    name: User.suggest_name(address),
                    password: random_password
                  )
                  reviewable = ReviewableUser.find_by(target: user)
                  reviewable&.perform(Discourse.system_user, :approve_user, send_email: true)
                  user.activate
                  ::ExtractionHandler.send_user_email(user.email, user.username, random_password, topic_id, false)
                else
                  user = User.create!(
                    email: address,
                    username: ::ExtractionHandler.generate_random_user(),
                    name: User.suggest_name(address),
                    staged: true
                  )
                  if SiteSetting.email_extraction_notify_staged_user
                    ::ExtractionHandler.send_user_email(user.email, user.username, nil, topic_id, true)
                  end
                end
              rescue Exception => e
                puts e.message
                puts e.backtrace.inspect
                user = nil
              end
            else
              ::ExtractionHandler.send_user_email(user.email, user.username, nil, topic_id, false)
            end
          end
          @users << user
          max_users += 1
        else
          break
        end
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
        begin
          @mail = Mail.new(entry.raw_email)
          from_user = User.find_by_email(@mail.from)
          if from_user.staged && SiteSetting.email_extraction_notify_staged_user
            ::ExtractionHandler.send_user_email(from_user.email, from_user.username, nil, entry.topic_id, true)
          end
          @all_emails = []
          #cc'd users aren't included in the body so we have to pull those manually.
          @cc_users = @mail.cc&.map(&:downcase)
          if !@cc_users.nil?
            @all_emails = @all_emails + @cc_users
          end

          @body_emails = @mail.body.to_s.upcase.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/).uniq
          @body_emails = ::ExtractionHandler.delete_email_element(@mail.to.to_s.upcase, @mail.from.to_s.upcase, @body_emails)

          if !@body_emails.nil?
            @all_emails = @all_emails + @body_emails
          end

          @all_users = ::ExtractionHandler.create_or_find_users(@all_emails, entry.topic_id)
          if @all_users.length > 0
            @all_users.each do |user|
              entry.topic.topic_allowed_users.create!(user_id: user.id)
              TopicUser.auto_notification_for_staging(user.id, entry.topic_id, TopicUser.notification_reasons[:auto_watch])
              entry.topic.add_small_action(Discourse.system_user, "invited_user", user.username)
          end
        end
      rescue Exception => e
        puts e.message
        puts e.inspect
      end
      end
    end

    #In certain scenarios, especially outlook clients, duplicate emails
    #are created with a substring of the existing emails. Here we just
    #remove anything in from/to and any variation of that.
    def self.delete_email_element(to_email, from, array)
      array.delete_if{ |email| email == to_email }
      array.delete_if{ |email| email == from }
      array.delete_if{ |email| to_email.include?(email)}
      array.delete_if{ |email| from.include?(email)}
      array
    end

    #Determien if we should allow extracting emails
    def self.extract_allowed?(entry)
      SiteSetting.email_extraction_enabled
    end

    #Send user creation email
    def self.send_user_email(to_address, username, password, topic_id, staged)
      if SiteSetting.email_extraction_notify_users
        if password.nil?
          if staged
            ExtractionEmailing::NewUserExtractionEmail.new.execute(template: 'email_extracted_staged_user', to_address: to_address, topic_id: topic_id)
          else
            ExtractionEmailing::NewUserExtractionEmail.new.execute(template: 'email_extracted_existing_user', to_address: to_address, topic_id: topic_id)
          end
        else
          ExtractionEmailing::NewUserExtractionEmail.new.execute(template: 'email_extracted_new_user', to_address: to_address, target_username: username, random_password: password, topic_id: topic_id)
        end
      end
    end
  end

  DiscourseEvent.on(:post_created || :topic_created) do |entry|
    if SiteSetting.email_extraction_enabled
      if entry.via_email
        if ::ExtractionHandler.extract_allowed?(entry)
          ::ExtractionHandler.extract_email_details(entry)
        end
      end
    end
  end
end
