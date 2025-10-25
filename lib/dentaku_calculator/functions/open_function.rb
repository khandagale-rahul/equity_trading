module DentakuCalculator
  module Functions
    class OpenFunction
      def self.current_context
        Thread.current[:dentaku_context] || {}
      end

      def self.register(calculator)
        calculator.add_functions([
          [
            :open,
            :numeric,
            ->(unit, interval, candle_number = 1) {
              instrument = OpenFunction.current_context[:instrument]

              instrument.open(
                unit: unit,
                interval: interval,
                number_of_candles: candle_number
              )[candle_number-1]
            }
          ]
        ])
      end
    end
  end
end
