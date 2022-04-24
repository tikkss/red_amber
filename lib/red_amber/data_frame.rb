# frozen_string_literal: true

module RedAmber
  class DataFrameArgumentError < ArgumentError; end
  class DataFrameTypeError < TypeError; end

  # data frame class
  #   @table   : holds Arrow::Table object
  class DataFrame
    def initialize(*args)
      @table = nil
      # ok: DataFrame.new, DataFrame.new([]), DataFrame.new(nil)
      #   returns empty DataFrame
      # bug in gobject-introspection: ruby-gnome/ruby-gnome#1472
      #  [Arrow::Table] == [nil] shows ArgumentError
      #  temporary use yoda condition to workaround
      return if args.empty? || args == [[]] || [nil] == args

      if args.size > 1
        @table = Arrow::Table.new(*args)
      else
        arg = args[0]
        @table =
          case arg
          when Arrow::Table        then arg
          when RedAmber::DataFrame then arg.table
          when Hash                then Arrow::Table.new(*args)
          else
            raise DataFrameTypeError, "invalid argument: #{args}"
          end
      end
    end

    def self.load(path, options: {})
      @table = Arrow::Table.load(path, options)
    end

    attr_reader :table

    # Properties ===
    def n_rows
      @table.n_rows
    end
    alias_method :nrow, :n_rows
    alias_method :size, :n_rows
    alias_method :length, :n_rows

    def n_columns
      @table.n_columns
    end
    alias_method :ncol, :n_columns
    alias_method :width, :n_columns

    def shape
      [n_rows, n_columns]
    end

    def column_names
      @table.columns.map { |column| column.name.to_sym }
    end
    alias_method :keys, :column_names
    alias_method :header, :column_names

    def types
      @table.columns.map { |column| column.data_type.to_s.to_sym }
    end

    def vectors
      @table.columns.map do |column|
        RedAmber::Vector.new(column.data)
      end
    end

    def to_s
      @table.to_s
    end

    def inspect
      format "#<#{self.class}:0x%016x>\n#{self}", object_id
    end

    # def describe() end

    # def summary() end

    # Output ===
    def to_h
      @table.columns.each_with_object({}) do |column, result|
        result[column.name.to_sym] = column.entries
      end
    end

    def to_a
      to_h.to_a
    end

    def raw_records
      # output an array of rows without header
      @table.raw_records
    end

    def to_rover
      require 'rover-df'
      Rover::DataFrame.new(to_h)
    end

    # def to_parquet

    # Selecting ===

    # select columns: [symbol] or [string]
    # select rows: [array of index], [range]
    def [](*args)
      raise DataFrameArgumentError, 'Empty argument' if args.empty?

      # expand Range like [1..3, 4] to [1, 2, 3, 4]
      expanded =
        args.each_with_object([]) do |e, a|
          e.is_a?(Range) ? a.concat(e.to_a) : a.append(e)
        end

      return select_rows(expanded) if integers?(expanded)
      return select_columns(expanded.map(&:to_sym)) if sym_or_str?(expanded)

      raise DataFrameArgumentError, "invalid argument #{args}"
    end

    def head(n_rows = 5)
      raise DataFrameArgumentError, "index is out of range #{n_rows}" if n_rows.negative?

      self[0...[n_rows, size].min]
    end

    def tail(n_rows = 5)
      raise DataFrameArgumentError, "index is out of range #{n_rows}" if n_rows.negative?

      self[-[n_rows, size].min..-1]
    end

    def first(n_rows = 1)
      head(n_rows)
    end

    def last(n_rows = 1)
      tail(n_rows)
    end

    private # =====

    def select_columns(keys)
      RedAmber::DataFrame.new(@table[keys])
    end

    def select_rows(indeces)
      if out_of_range?(indeces)
        raise DataFrameArgumentError, "invalid index: #{indeces} for [0..#{size - 1}]"
      end

      a = indeces.map { |i| @table.slice(i).to_a }
      RedAmber::DataFrame.new(@table.schema, a)
    end

    def out_of_range?(indeces)
      indeces.max >= size || indeces.min < -size
    end

    def integers?(enum)
      enum.all?(Integer)
    end

    def sym_or_str?(enum)
      enum.all? { |e| e.is_a?(Symbol) || e.is_a?(String) }
    end
  end
end
