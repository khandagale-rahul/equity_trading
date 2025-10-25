require_relative "functions/close_function"
require_relative "functions/open_function"

module DentakuCalculator
  class RegisterFunctions
    FUNCTION_CLASSES = [
      DentakuCalculator::Functions::CloseFunction,
      DentakuCalculator::Functions::OpenFunction
    ]

    def self.call(calculator)
      FUNCTION_CLASSES.each { |func| func.register(calculator) }
    end
  end
end
