require 'spec_helper'
require File.expand_path File.join(File.dirname(__FILE__), '..', 'lib', 'cabinet')

describe Cabinet do
  subject { Cabinet }

  describe "Faking it" do

    before do
      subject.fake_it
    end

    after do
      subject.keep_it_real
    end

    it "does not really create files" do
      file = subject.insert '/tmp/file'
      file.should be_an_instance_of Cabinet::File
      subject.has?('/tmp/file').should be_true
      file.should_not exist
    end
  end
end
