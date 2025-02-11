# frozen_string_literal: true

RSpec.describe Wampproto::Dealer do
  let(:session_id) { 123_456 }
  let(:request_id) { 1 }
  let(:procedure) { "com.hello.first" }
  let(:dealer) { described_class.new }
  let(:register) { Wampproto::Message::Register.new(request_id, {}, procedure) }

  context "when session is added" do
    before { dealer.add_session(session_id) }

    context "when procedure is registered" do
      subject { register_response.message }

      let(:register_response) { dealer.receive_message(session_id, register) }

      it { is_expected.to be_instance_of Wampproto::Message::Registered }

      context "when second procedure is registered" do
        subject { register_2_response.message }

        let(:second_procedure) { "com.second.procedure" }
        let(:register_2_response) { dealer.receive_message(session_id, register2) }
        let(:register2) { Wampproto::Message::Register.new(request_id + 1, {}, second_procedure) }

        before { register_response } # registers first procedure

        it { is_expected.to be_an_instance_of Wampproto::Message::Registered }

        context "when unregister both procedures" do
          let(:unregister_first) do
            Wampproto::Message::Unregister.new(request_id + 2, register_response.message.registration_id)
          end

          let(:unregister_second) do
            Wampproto::Message::Unregister.new(request_id + 3, register_2_response.message.registration_id)
          end

          before do
            register_2_response
            dealer.receive_message(session_id, unregister_first)
          end

          it "does not give any error" do
            expect(dealer.receive_message(session_id, unregister_second).message)
              .to be_an_instance_of(Wampproto::Message::Unregistered)
          end
        end
      end

      context "when session unregisters a procedure" do
        subject { unregister_response.message }

        let(:unregister) do
          Wampproto::Message::Unregister.new(request_id + 1, register_response.message.registration_id)
        end

        let(:unregister_response) { dealer.receive_message(session_id, unregister) }

        it { is_expected.to be_instance_of Wampproto::Message::Unregistered }

        context "when registration not found" do
          let(:unregister) { Wampproto::Message::Unregister.new(request_id + 1, 9999) }

          it { is_expected.to be_instance_of Wampproto::Message::Error }
        end
      end

      context "when call message is received from caller_id" do
        subject { call_response.message }

        before { register_response }

        let(:caller_id) { 456_789 }
        let(:call) { Wampproto::Message::Call.new(request_id, {}, procedure, 1) }
        let(:call_response) { dealer.receive_message(caller_id, call) }

        it { is_expected.to be_instance_of Wampproto::Message::Invocation }

        context "when calling unregistered procedure" do
          let(:call) { Wampproto::Message::Call.new(request_id, {}, "invalid.procedure", 1) }

          it { is_expected.to be_instance_of Wampproto::Message::Error }
        end

        context "when yield message received from the callee" do
          subject { yield_response.message }

          before { call_response }

          let(:yield_msg) { Wampproto::Message::Yield.new(request_id + 1, {}, 2) }
          let(:yield_response) { dealer.receive_message(session_id, yield_msg) }

          it { is_expected.to be_instance_of Wampproto::Message::Result }

          context "when session is removed" do
            subject { dealer.registrations_by_session }

            before { dealer.remove_session(session_id) }

            it { is_expected.to be_empty }

            context "when session does not exists" do
              it { expect { dealer.remove_session(caller_id) }.to raise_exception(KeyError) }
            end
          end
        end
      end
    end
  end
end
