require 'email/build_email_helper'

class NewUserMailer < ActionMailer::Base

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
