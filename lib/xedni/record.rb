module Xedni
  class Record
    attr :id, :keywords, :collections
    def initialize(attrs={})
      @id = attrs[:id]
      @keywords = (attrs[:keywords] || [] ).map(&:to_s)
      @collections = (attrs[:collections] || {}).stringify_keys
    end
    def save
    end
  end
end
