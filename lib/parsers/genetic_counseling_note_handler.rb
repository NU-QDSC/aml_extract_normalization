module Parsers
  # Define your own SAX handler class by inheriting from Nokogiri's SAX::Document class
  class GeneticCounselingNoteHandler < Nokogiri::XML::SAX::Document
    attr_accessor :genetic_counseling_notes
    def initialize
      @current_element = nil
      @genetic_counseling_notes = []
      @current_genetic_counseling_note = nil
    end

    # Callback method triggered when an element starts
    def start_element(name, attrs = [])
      @current_element = name
      if name == 'Detail'
        @current_genetic_counseling_note = Parsers::GeneticCounselingNote.new
      end
      @characters = ""
    end

    # Callback method triggered when an element ends
    def end_element(name)
      if name == 'Detail'
        @genetic_counseling_notes << @current_genetic_counseling_note
      end
      @current_element = nil
    end

    # Callback method triggered when text content is encountered within an element
    def characters(string)
      if @current_genetic_counseling_note && @current_genetic_counseling_note.fields.include?(@current_element.to_sym)
        @characters += string
        @current_genetic_counseling_note.instance_variable_set("@#{@current_element}", @characters)
      end
    end
  end
end