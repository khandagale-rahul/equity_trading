require Rails.root.join("lib/dentaku_calculator/register_functions")

CALCULATOR = Dentaku::Calculator.new
DentakuCalculator::RegisterFunctions.call(CALCULATOR)
