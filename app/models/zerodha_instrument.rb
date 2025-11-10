require "csv"

class ZerodhaInstrument < Instrument
  LIST = %w[NSE].freeze

  has_one :master_instrument, foreign_key: :zerodha_instrument_id

  def self.import_instruments(api_key:, access_token:)
    api_service = Zerodha::ApiService.new(api_key: api_key, access_token: access_token)
    api_service.instruments

    if api_service.response[:status] == "success"
      csv_data = CSV.parse(api_service.response[:data], headers: :first_row)

      csv_data.each do |row|
        if ZerodhaInstrument::LIST.include?(row["exchange"]) && row["instrument_type"] == "EQ"
          instrument = self.find_or_initialize_by(
            identifier: row["instrument_token"]
          )

          instrument.symbol = row["tradingsymbol"]
          instrument.name = row["name"]
          instrument.exchange = row["exchange"]
          instrument.segment = row["segment"]
          instrument.exchange_token = row["exchange_token"]
          instrument.tick_size = row["tick_size"].to_f
          instrument.lot_size = row["lot_size"].to_i
          instrument.raw_data = row.to_h

          if instrument.save
            MasterInstrument.create_from_exchange_data(
              name: instrument.name,
              instrument: instrument,
              exchange: instrument.exchange,
              exchange_token: instrument.exchange_token
            )
          end
        end
      end
    end
    nil
  end

  def self.update_ltps
  end
end
