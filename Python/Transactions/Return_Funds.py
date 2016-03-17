##
# BluePay Python Sample code.
#
# This code sample runs a $3.00 Credit Card Sale transaction
# against a customer using test payment information. If
# approved, a 2nd transaction is run to partially refund the 
# customer for $1.75 of the $3.00.
# If using TEST mode, odd dollar amounts will return
# an approval and even dollar amounts will return a decline.
##

import os.path, sys
sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), os.pardir))
from BluePay import BluePay

account_id = "100228390579"
secret_key = "AKGIF9X9WT9CLQCWDFONC8N3HXRL9Y5K"
mode = "TEST"

payment = BluePay(
    account_id = account_id, # Merchant's Account ID
    secret_key = secret_key, # Merchant's Secret Key
    mode = mode # Transaction Mode: TEST (can also be LIVE)
)

# Set Customer Information
payment.set_customer_information(
    name1 = "Bob",
    name2 = "Tester",
    addr1 = "123 Test St.",
    addr2 = "Apt #500",
    city = "Testville",
    state = "IL",
    zipcode = "54321",
    country = "USA"
)

# Set Credit Card Information
payment.set_cc_information(
    card_number = "4111111111111111",
    card_expire = "1215",
    cvv2 = "123"
)

payment.sale(amount = '3.00') # Sale Amount: $3.00

# Makes the API Request for processing the sale
payment.process()

# If transaction was approved..
if payment.is_successful_response():

    payment_return = BluePay(
        account_id = account_id, # Merchant's Account ID
        secret_key = secret_key, # Merchant's Secret Key
        mode = mode # Transaction Mode: TEST (can also be LIVE)
    )

    # Creates a refund transaction against previous sale
    payment_return.refund(
        transaction_id = payment.trans_id_response, # id of the transaction to refund
        amount = '1.75' # partial refund of $1.75
    )

    # Makes the API Request for processing the sale
    payment_return.process()

    # Read response from BluePay
    print 'Transaction Status: ' + payment_return.status_response
    print 'Transaction Message: ' + payment_return.message_response
    print 'Transaction ID: ' + payment_return.trans_id_response
    print 'AVS Response: ' + payment_return.avs_code_response
    print 'CVV2 Response: ' + payment_return.cvv2_code_response
    print 'Masked Payment Account: ' + payment_return.masked_account_response
    print 'Card Type: ' + payment_return.card_type_response
    print 'Auth Code: ' + payment_return.auth_code_response
else:
    print payment_return.message_response