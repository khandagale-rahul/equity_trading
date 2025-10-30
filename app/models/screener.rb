class Screener < ApplicationRecord
  include ScreenerConcern

  attr_accessor :master_instrument

  belongs_to :user
  validates :name,
            :rules,
            presence: true

  validate :validate_rules_syntax

  def scan
    filtered_master_instrument_ids = []

    ActiveRecord::Base.transaction(requires_new: true) do
      MasterInstrument.joins(:upstox_instrument).find_each(batch_size: 100) do |master_instrument|
        break if self.errors.present?

        if evaluate_rule(master_instrument)
          filtered_master_instrument_ids << master_instrument.id
        end
      end
      raise ActiveRecord::Rollback
    end

    self.update(scanned_instrument_ids: filtered_master_instrument_ids)
    filtered_master_instrument_ids
  end

  def master_instruments
    MasterInstrument.joins(:upstox_instrument).where(id: scanned_instrument_ids)
  end

  private

    def validate_rules_syntax
      return unless rules.present?

      # Check for potentially dangerous code patterns
      dangerous_patterns = [
        # System/Command execution
        /\bsystem\b/i,
        /\bexec\b/i,
        /\b`/,
        /\bspawn\b/i,
        /\bfork\b/i,
        /\bopen\b.*\|/,  # open("|command")
        /\bIO\.popen\b/i,
        /\bIO\.read\b/i,
        /\bIO\.write\b/i,
        /\bIO\.binread\b/i,
        /\bIO\.binwrite\b/i,

        # Code evaluation and reflection
        /\beval\b/i,
        /\bsend\b/i,
        /\b__send__\b/i,
        /\bpublic_send\b/i,
        /\bmethod\b/i,
        /\bdefine_method\b/i,
        /\bclass_eval\b/i,
        /\binstance_eval\b/i,
        /\bmodule_eval\b/i,
        /\binstance_exec\b/i,
        /\bclass_exec\b/i,
        /\bmodule_exec\b/i,

        # File/Directory operations
        /\bFile\b/,
        /\bDir\b/,
        /\bIO\b/,
        /\bPathname\b/,
        /\bFileUtils\b/i,
        /\bTempfile\b/i,

        # Require/Load
        /\brequire\b/i,
        /\brequire_relative\b/i,
        /\bload\b/i,
        /\bautoload\b/i,

        # Dangerous classes/modules
        /\bKernel\b/,
        /\bObjectSpace\b/,
        /\bBinding\b/,
        /\bProcess\b/,
        /\bThread\b/,
        /\bMutex\b/,

        # Lambda/Proc creation
        /\bProc\b/,
        /\blambda\b/,
        /\b->\b/,
        /\bproc\b\s*\{/,

        # Constant manipulation
        /\bconst_get\b/i,
        /\bconst_set\b/i,
        /\bconst_missing\b/i,
        /\bremove_const\b/i,

        # Database write operations
        /\bdestroy\b/i,
        /\bdelete\b/i,
        /\bupdate\b/i,
        /\bsave\b/i,
        /\bcreate\b/i,
        /\bupdate_all\b/i,
        /\bdelete_all\b/i,
        /\bdestroy_all\b/i,
        /\bupdate_attribute\b/i,
        /\bupdate_column\b/i,
        /\bincrement\b/i,
        /\bdecrement\b/i,
        /\btoggle\b/i,
        /\btouch\b/i,
        /\binsert\b/i,
        /\binsert_all\b/i,
        /\bupsert\b/i,
        /\bupsert_all\b/i,
        /\btruncate\b/i,

        # Class/Module manipulation
        /\bClass\.new\b/i,
        /\bModule\.new\b/i,
        /\binclude\b/i,
        /\bextend\b/i,
        /\bprepend\b/i,
        /\balias_method\b/i,
        /\bdefine_singleton_method\b/i,
        /\bundef_method\b/i,
        /\bremove_method\b/i,

        # Global variable access
        /\$\w+/,  # $global_var

        # Environment manipulation
        /\bENV\b/,
        /\bExit\b/i,
        /\bexit\b/i,
        /\babort\b/i,
        /\braise\b/i,
        /\bfail\b/i,
        /\bthrow\b/i,

        # Network/HTTP
        /\bNet::/i,
        /\bURI\b/,
        /\bHTTP\b/i,
        /\bSocket\b/i,
        /\bTCPSocket\b/i,
        /\bUDPSocket\b/i,

        # Database connection manipulation
        /\bActiveRecord::Base\.connection\b/i,
        /\bActiveRecord::Base\.establish_connection\b/i,
        /\bexecute\b.*sql/i,

        # YAML/Marshal (deserialization attacks)
        /\bYAML\.load\b/i,
        /\bMarshal\.load\b/i,
        /\bMarshal\.restore\b/i
      ]

      dangerous_patterns.each do |pattern|
        if rules.match?(pattern)
          errors.add(:rules, "contains potentially dangerous code pattern")
          return
        end
      end

      ActiveRecord::Base.transaction(requires_new: true) do
        begin
          sample_master_instrument = MasterInstrument.find_by(exchange_token: "2885")

          unless sample_master_instrument
            errors.add(:rules, "cannot be validated - no instruments available")
          end

          evaluate_rule(sample_master_instrument)
        end

        raise ActiveRecord::Rollback
      end
    end

    def evaluate_rule(master_instrument)
      result = nil
      @calculated_data = {}
      begin
        return unless rules.present?

        self.master_instrument = master_instrument
        result = eval(rules.squish)
      rescue
        errors.add(:rules, "is invalid")
      end

      result
    end
end
