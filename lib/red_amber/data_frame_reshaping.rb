# frozen_string_literal: true

module RedAmber
  # mix-ins for the class DataFrame
  module DataFrameReshaping
    # Transpose a wide DataFrame.
    #
    # @param key [Symbol, FalseClass] key of the index column
    #   to transepose into keys.
    #   If it is false, keys[0] is used.
    # @param new_key [Symbol, FalseClass] key name of transposed index column.
    #   If it is false, :name is used. If it already exists, :name1.succ is used.
    # @return [DataFrame] trnsposed DataFrame
    def transpose(key: keys.first, new_key: :name)
      raise DataFrameArgumentError, "Not include: #{key}" unless keys.include?(key)

      # Find unused name
      new_keys = self[key].to_a.map { |e| e.to_s.to_sym }
      new_key = (:name1..).find { |k| !new_keys.include?(k) } if new_keys.include?(new_key)

      hash = { new_key => (keys - [key]) }
      i = keys.index(key)
      each_row do |h|
        k = h.values[i]
        hash[k] = h.values - [k]
      end
      DataFrame.new(hash)
    end

    # Reshape wide DataFrame to a longer DataFrame.
    #
    # @param keep_keys [Array] keys to keep.
    # @param name [Symbol, String] key of the column which is come **from values**.
    # @param value [Symbol, String] key of the column which is come **from values**.
    # @return [DataFrame] long DataFrame.
    def to_long(*keep_keys, name: :name, value: :value)
      not_included = keep_keys - keys
      raise DataFrameArgumentError, "Not have keys #{not_included}" unless not_included.empty?

      name = name.to_sym
      raise DataFrameArgumentError, "Invalid key: #{name}" if keep_keys.include?(name)

      value = value.to_sym
      raise DataFrameArgumentError, "Invalid key: #{value}" if keep_keys.include?(value)

      hash = Hash.new { |h, k| h[k] = [] }
      l = keys.size - keep_keys.size
      each_row do |row|
        row.each do |k, v|
          if keep_keys.include?(k)
            hash[k].concat([v] * l)
          else
            hash[name] << k
            hash[value] << v
          end
        end
      end
      DataFrame.new(hash)
    end
  end
end
