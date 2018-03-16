require_dependency 'email/message_builder'

class NewUserMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_email(template, to_address, target_username, random_password, topic)
    if target_username.nil?
      build_email(
        to_address,
        template: template,
        topic: topic
      )
    else
      build_email(
        to_address,
        template: template,
        new_username: target_username,
        random_password: random_password,
        topic: topic
      )
    end
  end
end
