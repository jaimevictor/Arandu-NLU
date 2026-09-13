# frozen_string_literal: true

module P02Fallback
  class InvalidTable < StandardError; end
  class InvalidInput < StandardError; end

  class ExactByteMatcher
    MAX_ENTRIES = 65_536
    MAX_INPUT_BYTES = 65_536
    MAX_TARGET_ID = (1 << 63) - 1

    attr_reader :size

    def initialize(entries)
      unless entries.is_a?(Array) && entries.length <= MAX_ENTRIES
        raise InvalidTable, "entry table is not a bounded array"
      end

      rows = entries.each_with_index.map do |entry, index|
        unless entry.is_a?(Array) && entry.length == 2
          raise InvalidTable, "entry #{index} is not a key-target pair"
        end

        key = validated_bytes(
          entry.fetch(0),
          InvalidTable,
          "entry #{index} key"
        )
        target = entry.fetch(1)
        unless target.is_a?(Integer) && target.between?(0, MAX_TARGET_ID)
          raise InvalidTable, "entry #{index} target is outside the allowed range"
        end

        [key, target].freeze
      end

      rows.sort_by!(&:first)
      rows.each_cons(2) do |left, right|
        raise InvalidTable, "duplicate entry key" if left.fetch(0) == right.fetch(0)
      end

      @rows = rows.freeze
      @size = rows.length
      freeze
    end

    def lookup(input)
      key = validated_bytes(input, InvalidInput, "query")
      lower = 0
      upper = @rows.length

      while lower < upper
        middle = lower + ((upper - lower) / 2)
        if @rows.fetch(middle).fetch(0) < key
          lower = middle + 1
        else
          upper = middle
        end
      end

      return nil if lower == @rows.length

      row = @rows.fetch(lower)
      row.fetch(0) == key ? row.fetch(1) : nil
    end

    private

    def validated_bytes(value, error_class, label)
      unless value.is_a?(String) && value.encoding == Encoding::UTF_8
        raise error_class, "#{label} is not a UTF-8 string"
      end
      unless value.valid_encoding?
        raise error_class, "#{label} contains malformed UTF-8"
      end
      unless value.bytesize.between?(1, MAX_INPUT_BYTES)
        raise error_class, "#{label} byte length is outside the allowed range"
      end

      bytes = value.dup
      bytes.force_encoding(Encoding::BINARY)
      bytes.freeze
    end
  end
end
