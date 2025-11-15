# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe CleanupJobLogsJob, type: :job do
  before(:all) do
    Rails.application.load_tasks
  end

  describe '#perform' do
    let(:rake_task) { Rake::Task['job_logs:cleanup'] }

    before do
      allow(rake_task).to receive(:reenable)
      allow(rake_task).to receive(:invoke)
    end

    it 'reenables and invokes the job_logs:cleanup rake task with default days' do
      described_class.new.perform

      expect(rake_task).to have_received(:reenable)
      expect(rake_task).to have_received(:invoke).with(7)
    end

    it 'reenables and invokes the job_logs:cleanup rake task with custom days' do
      described_class.new.perform(days: 14)

      expect(rake_task).to have_received(:reenable)
      expect(rake_task).to have_received(:invoke).with(14)
    end

    it 'can be enqueued' do
      expect {
        described_class.perform_async
      }.to change(described_class.jobs, :size).by(1)
    end
  end
end
