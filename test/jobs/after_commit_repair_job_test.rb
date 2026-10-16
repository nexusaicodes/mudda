require "test_helper"

class AfterCommitRepairJobTest < ActiveJob::TestCase
  test "performs the side effect in the enqueuing account" do
    card = cards(:logo)
    Search::Record.where(searchable_type: "Card", searchable_id: card.id).delete_all

    AfterCommitRepairJob.perform_later(card, "reindex")
    perform_enqueued_jobs

    assert Search::Record.exists?(searchable_type: "Card", searchable_id: card.id)
  end

  test "a side effect on a class, such as removing a deleted record from the index, is repaired" do
    card = cards(:logo)
    card.reindex

    AfterCommitRepairJob.perform_later(Card, "remove_from_search_index", card.id)
    perform_enqueued_jobs

    assert_not Search::Record.exists?(searchable_type: "Card", searchable_id: card.id)
  end

  test "a receiver deleted since is discarded without a report" do
    note = notes(:logo_agreement_kevin)
    AfterCommitRepairJob.perform_later(note, "reindex")
    note.delete

    assert_no_error_reported { perform_enqueued_jobs }
  end

  test "a side effect that keeps failing is retried, then reported" do
    Card.any_instance.stubs(:reindex).raises(ActiveRecord::StatementInvalid, "index unavailable")
    AfterCommitRepairJob.perform_later(cards(:logo), "reindex")

    assert_error_reported(ActiveRecord::StatementInvalid) do
      8.times { perform_enqueued_jobs rescue nil }
    end
  end
end
