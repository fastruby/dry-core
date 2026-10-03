# Ractor smoke test for dry-core.
#
# Defines classes using each dry-core module in the main Ractor, then checks
# whether they work from a non-main Ractor.
#
# Run from the repo root:
#
#   bundle exec ruby script/ractor_smoke.rb

Warning[:experimental] = false
require "dry/core"

class Point
  include Dry::Core::Equalizer.new(:x, :y)
  attr_reader :x, :y
  def initialize(x, y) = (@x, @y = x, y)
end

class WithAttrs
  extend Dry::Core::ClassAttributes
  defines :adapter
  adapter :sql
end

class Cached
  extend Dry::Core::Cache
  def self.compute(k) = fetch_or_store(k) { k.to_s * 2 }
end
Cached.compute(:warm) # populate the cache in main

class Memo
  include Dry::Core::Memoizable
  def value = 42
  memoize :value
end

class Base
  extend Dry::Core::DescendantsTracker
end
class Child < Base; end

class MyContainer
  extend Dry::Core::Container::Mixin
  register(:greeting, "hello")
  register(:lazy) { "built" }
end

module Deps
  extend Dry::Core::Deprecations[:smoke]
end

puts "Ruby #{RUBY_VERSION}, dry-core #{Dry::Core::VERSION}"
puts "-" * 70

tests = {
  "Constants (EMPTY_HASH, Undefined)"       => -> { Ractor.new { [Dry::Core::Constants::EMPTY_HASH, Dry::Core::Constants::Undefined.default(Dry::Core::Constants::Undefined, 1)] }.value },
  "Equalizer: Point.new + == in Ractor"     => -> { Ractor.new { Point.new(1, 2) == Point.new(1, 2) }.value },
  "Equalizer: inspect in Ractor"            => -> { Ractor.new { Point.new(1, 2).inspect }.value },
  "Equalizer: pass frozen Point in"         => -> { Ractor.new(Ractor.make_shareable(Point.new(1, 2))) { |p| p.hash.is_a?(Integer) }.value },
  "ClassAttributes: read Klass.adapter"     => -> { Ractor.new { WithAttrs.adapter }.value },
  "Cache: fetch_or_store (cached key)"      => -> { Ractor.new { Cached.compute(:warm) }.value },
  "Cache: fetch_or_store (new key)"         => -> { Ractor.new { Cached.compute(:new) }.value },
  "Memoizable: Memo.new.value in Ractor"    => -> { Ractor.new { Memo.new.value }.value },
  "DescendantsTracker: Base.descendants"    => -> { Ractor.new { Base.descendants.map(&:name) }.value },
  "Container: resolve registered value"     => -> { Ractor.new { MyContainer[:greeting] }.value },
  "Container: resolve lazy block"           => -> { Ractor.new { MyContainer[:lazy] }.value },
  "Deprecations: warn in Ractor"            => -> { Ractor.new { Deps.warn("x"); :warned }.value },
  "ClassBuilder: build class in Ractor"     => -> { Ractor.new { Dry::Core::ClassBuilder.new(name: "Built").call.name }.value },
  "Define class w/ ClassAttributes in Ractor" => -> { Ractor.new { Class.new { extend Dry::Core::ClassAttributes; defines :a; a 1 }.a }.value },
}

results = tests.map do |name, test|
  print "#{name.ljust(44)} "
  begin
    out = test.call
    puts "OK (#{out.inspect[0, 40]})"
    [name, :ok]
  rescue Ractor::RemoteError => e
    c = e.cause
    loc = c.backtrace&.find { _1.include?("dry-core") }&.then { " @ " + _1[%r{lib/dry/core/[^:]+:\d+}].to_s }
    puts "FAILED: #{c.class}: #{c.message.lines.first.strip[0, 110]}#{loc}"
    [name, :fail]
  rescue => e
    puts "FAILED: #{e.class}: #{e.message.lines.first.strip[0, 110]}"
    [name, :fail]
  end
end
puts "-" * 70
puts "#{results.count { _2 == :ok }}/#{results.size} passed"
