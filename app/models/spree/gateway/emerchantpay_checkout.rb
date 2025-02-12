module Spree
  # Emerchantpay Checkout Payment Method
  class Gateway::EmerchantpayCheckout < SpreeEmerchantpayGenesis::Base::Gateway # rubocop:disable Style/ClassAndModuleChildren

    preference :transaction_types, :multi_select,  default: lambda {
      { values: GenesisRuby::Utils::Transactions::WpfTypes.all }
    }
    preference :return_cancel_url, :string, default: 'http://localhost:4000/checkout/payment'
    preference :return_pending_url, :string, default: 'http://localhost:4000/orders/|:ORDER:|'

    delegate :load_data, :load_source, :load_payment, to: :provider

    def method_type
      SpreeEmerchantpayGenesis::PaymentMethodHelper::CHECKOUT_PAYMENT
    end

    def purchase(_money_in_cents, source, gateway_options)
      order, payment = order_data_from_options gateway_options
      user           = order.user

      prepare_provider(
        SpreeEmerchantpayGenesis::Mappers::Order.prepare_data(order, user, gateway_options),
        source,
        payment
      )

      provider.purchase
    end

    def source_required?
      true
    end

    def payment_source_class
      EmerchantpayCheckoutSource
    end

    def auto_capture?
      false
    end

    private

    # Prepare provider
    def prepare_provider(data, source, payment)
      load_data SpreeEmerchantpayGenesis::Mappers::Order.for data
      load_source source
      load_payment payment
    end

  end
end
