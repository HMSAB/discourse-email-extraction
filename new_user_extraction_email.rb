require_dependency 'email/sender'
require_dependency 'sidekiq'
require_relative 'new_user_mailer'

module ExtractionEmailing
  class NewUserExtractionEmail
    include Sidekiq::Worker

    sidekiq_options queue: 'critical'

    def execute(args)
      template = args[:template]
      to_address = args[:to_address]
      target_username = args[:target_username]
      random_password = args[:random_password]
      topic_id = args[:topic_id]

      raise Discourse::InvalidParameters.new(:template) if template.blank?
      raise Discourse::InvalidParameters.new(:to_address) if to_address.blank?
      raise Discourse::InvalidParameters.new(:topic_id) if topic_id.blank?
      
      if template == 'email_extracted_new_user'
        raise Discourse::InvalidParameters.new(:target_username) if target_username.blank?
        raise Discourse::InvalidParameters.new(:random_password) if random_password.blank?
        message = NewUserMailer.send_email(template, to_address, target_username, random_password, topic_id)
      else
        message = NewUserMailer.send_email(template, to_address, nil, nil, topic_id)
      end
      Email::Sender.new(message, :email_extracted_new_user).send
    end

  end
end
