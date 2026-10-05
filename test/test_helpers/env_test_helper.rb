# Sets ENV for the length of a block and puts it back after. Parallel workers are processes,
# so one test's ENV never reaches another's.
module EnvTestHelper
  def with_env(vars)
    saved = vars.keys.to_h { |key| [ key, ENV[key] ] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end
end
