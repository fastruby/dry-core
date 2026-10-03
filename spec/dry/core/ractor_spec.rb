# frozen_string_literal: true

RSpec.describe "Ractor compatibility", if: defined?(Ractor) do
  around do |example|
    experimental = Warning[:experimental]
    Warning[:experimental] = false
    example.run
  ensure
    Warning[:experimental] = experimental
  end

  def in_ractor(&block)
    Ractor.new(&block).value
  end

  before do
    module Test
      class WithClassAttributes
        extend Dry::Core::ClassAttributes

        defines :one
        one 1
      end

      class WithEqualizer
        include Dry::Core::Equalizer.new(:a)

        attr_reader :a

        def initialize(a) = @a = a
      end
    end
  end

  it "reads class attributes from a non-main Ractor" do
    expect(in_ractor { Test::WithClassAttributes.one }).to eq(1)
  end

  it "compares equalizer objects from a non-main Ractor" do
    expect(in_ractor { Test::WithEqualizer.new(1) == Test::WithEqualizer.new(1) }).to be(true)
  end

  it "hashes equalizer objects from a non-main Ractor" do
    expect(in_ractor { Test::WithEqualizer.new(1).hash }).to be_an(Integer)
  end

  it "inspects equalizer objects from a non-main Ractor" do
    expect(in_ractor { Test::WithEqualizer.new(1).inspect }).to eq("#<Test::WithEqualizer a=1>")
  end
end
