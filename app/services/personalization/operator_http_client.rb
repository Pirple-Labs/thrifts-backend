# frozen_string_literal: true

module Personalization
  # Back-compat shim to avoid NameError when rescuing Operator errors in legacy code paths.
  class OperatorHttpClient
    class Error < StandardError; end
  end
end


