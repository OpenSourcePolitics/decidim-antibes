# frozen_string_literal: true

require "spec_helper"

module Decidim
  describe CreateRegistration do
    describe "call" do
      let(:organization) { create(:organization) }

      let(:name) { "Username" }
      let(:nickname) { "nickname" }
      let(:email) { "user@example.org" }
      let(:password) { "Y1fERVzL2F" }
      let(:password_confirmation) { password }
      let(:tos_agreement) { "1" }
      let(:newsletter) { "1" }
      let(:current_locale) { "es" }
      let(:situation) { "living" }
      let(:registration_metadata) do
        {
          sworn_statement: "1",
          cq_interested: "1",
          situation: situation,
          address: "282 Kevin Brook, Imogeneborough, CA 58517"
        }
      end

      let(:form_params) do
        {
          "user" => {
            "name" => name,
            "nickname" => nickname,
            "email" => email,
            "password" => password,
            "password_confirmation" => password_confirmation,
            "tos_agreement" => tos_agreement,
            "newsletter_at" => newsletter,
            "registration_metadata" => registration_metadata
          }
        }
      end
      let(:form) do
        RegistrationForm.from_params(
          form_params,
          current_locale: current_locale
        ).with_context(
          current_organization: organization
        )
      end
      let(:command) { described_class.new(form) }

      describe "when the form is not valid" do
        before do
          expect(form).to receive(:invalid?).and_return(true)
        end

        it "broadcasts invalid" do
          expect { command.call }.to broadcast(:invalid)
        end

        it "doesn't create a user" do
          expect do
            command.call
          end.not_to change(User, :count)
        end

        context "when the user was already invited" do
          let(:user) { build(:user, email: email, organization: organization) }

          before do
            user.invite!
            clear_enqueued_jobs
          end

          it "receives the invitation email again" do
            expect do
              command.call
              user.reload
            end.to change(User, :count).by(0)
                                       .and broadcast(:invalid)
              .and change(user.reload, :invitation_token)
            expect(ActionMailer::DeliveryJob).to have_been_enqueued.on_queue("mailers")
          end
        end
      end

      describe "when the form is valid" do
        it "broadcasts ok" do
          expect { command.call }.to broadcast(:ok)
        end

        it "creates a new user" do
          expect(User).to receive(:create!).with(
            name: form.name,
            nickname: form.nickname,
            email: form.email,
            password: form.password,
            password_confirmation: form.password_confirmation,
            tos_agreement: form.tos_agreement,
            newsletter_notifications_at: form.newsletter_at,
            email_on_notification: true,
            organization: organization,
            accepted_tos_version: organization.tos_version,
            locale: form.current_locale,
            registration_metadata: form.registration_metadata
          ).and_call_original

          expect { command.call }.to change(User, :count).by(1)
        end

        describe "when user keeps the newsletter unchecked" do
          let(:newsletter) { "0" }

          it "creates a user with no newsletter notifications" do
            expect do
              command.call
              expect(User.last.newsletter_notifications_at).to eq(nil)
            end.to change(User, :count).by(1)
          end
        end

        context "when registration metadata contains living situation" do
          let(:situation) { "living" }

          it "sets address to nil" do
            expect do
              command.call
              expect(User.last.registration_metadata["address"]).not_to eq(nil)
            end.to change(User, :count).by(1)
          end
        end

        context "when registration metadata does not contains living situation" do
          let(:situation) { "other" }

          it "sets address to nil" do
            expect do
              command.call
              expect(User.last.registration_metadata["address"]).to eq(nil)
            end.to change(User, :count).by(1)
          end
        end
      end
    end
  end
end
