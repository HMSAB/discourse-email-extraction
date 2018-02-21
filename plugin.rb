
# name: email-extraction
# about: Extract and invite CC'd users to topic
# version: 0.1
# authors: Jordan Seanor
# url: https://github.com/HMSAB/discourse-email-extraction.git


enabled_site_setting :email_extraction_enabled

after_initialize do

  class ::ExtractionHandler

    def self.extract_email_details(entry)
      if !entry.raw_email.empty?
        @mail = Mail.new(entry.raw_email)
        @to = @mail[:to]
        @cc = @mail[:cc]
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
