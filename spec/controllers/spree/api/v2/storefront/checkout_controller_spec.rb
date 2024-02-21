RSpec.describe Spree::Api::V2::Storefront::CheckoutController, :vcr, type: :controller do
  let(:user) { create :user }
  let(:order) { OrderWalkthrough.up_to :payment }

  before do
    allow(controller).to receive_messages try_spree_current_user: user
    allow(controller).to receive_messages spree_current_user: user
    allow(controller).to receive_messages spree_current_order: order
    allow(controller).to receive_messages order_token: Faker::String.random
    allow(controller).to receive_messages spree_authorize!: nil
  end

  describe 'when create_payment' do
    let(:payment) do
      create :emerchantpay_direct_payment,
             payment_method: create(:emerchantpay_direct_gateway),
             source: create(:credit_card_params)
    end
    let(:params) do
      {
        payment_method_id: payment.payment_method.id,
        source_attributes: {
          name:               'Dimitar Natskin',
          number:             '4938730000000001',
          month:              1,
          year:               2023,
          verification_value: '123',
          cc_type:            'visa',
          accept_header:      '*/*',
          java_enabled:       'true',
          language:           'en-GB',
          color_depth:        '32',
          screen_height:      '400',
          screen_width:       '400',
          time_zone_offset:   '+0',
          user_agent:         'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)' \
                                ' Chrome/118.0.0.0 Safari/537.36'
        }
      }
    end

    before do
      allow(order).to receive_messages state: 'payment'
      allow(controller).to receive_messages check_authorization: true
    end

    it 'when payment with error' do
      post :create_payment, params: params

      expect(response.body)
        .to eq({ error: 'Please check input data for errors! (\'currency\' not supported by this Terminal)' }.to_json)
    end

    describe 'when successful payment' do
      it 'with approved payment state' do
        post :create_payment, params: params

        expect(JSON.parse(response.body)['data']['emerchantpay_payment'])
          .to eq({ 'state' => 'approved', 'redirect_url' => "http://localhost:4000/orders/#{order.number}" })
      end

      it 'with pending payment state with 3dsv2 method continue' do
        post :create_payment, params: params

        expect(JSON.parse(response.body)['data']['emerchantpay_payment'])
          .to eq({ 'state' => 'pending_async', 'redirect_url' => 'http://127.0.0.1:4000/emerchantpay_threeds/' \
                   'e6f86c7ca3b665e29f6d6c6eeb927788/4ac9f028afcd081bad7574daf12843fd' })
      end

      it 'with pending payment with redirect url' do
        post :create_payment, params: params

        expect(JSON.parse(response.body)['data']['emerchantpay_payment'])
          .to eq({ 'state' => 'pending_async', 'redirect_url' => 'https://staging.gate.emerchantpay.net/threeds/' \
                   'authentication/162d90bf750a62392b12a88010426ccd' })
      end
    end
  end

  describe 'when non emerchantpay payment method' do
    let(:order) { OrderWalkthrough.up_to :payment }
    let(:payment) { create(:payment) }
    let(:params) do
      {
        payment_method_id: payment.payment_method.id,
        source_attributes: {
          gateway_payment_profile_id: 'card_1JqvNB2eZvKYlo2C5OlqLV7S',
          cc_type:                    'visa',
          last_digits:                '1111',
          month:                      10,
          year:                       2026,
          name:                       'John Snow'
        }
      }
    end

    before do
      allow(order).to receive_messages state: 'payment'
      allow(controller).to receive_messages check_authorization: true
    end

    it 'with success payment response' do
      post :create_payment, params: params

      expect(response).to have_http_status :created
    end

    it 'with invalid payment params' do
      params.delete :source_attributes
      post :create_payment, params: params

      expect(response.body).to eq({ error: 'missing_attributes', errors: {} }.to_json)
    end
  end
end
