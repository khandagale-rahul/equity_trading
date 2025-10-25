module DentakuCalculator
  module Functions
    class CloseFunction
      def self.current_context
        Thread.current[:dentaku_context] || {}
      end

      def self.register(calculator)
        calculator.add_functions([
          [
            :close,
            :numeric,
            ->(unit, interval, candle_number = 1) {
              instrument = CloseFunction.current_context[:instrument]

              instrument.close(
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
