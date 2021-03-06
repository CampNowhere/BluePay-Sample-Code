package BluePay;

$VERSION = '1.10';
use strict;
use warnings;
# Required modules
use Digest::MD5 qw(md5_hex);
use Crypt::Digest::SHA512 qw(sha512_hex);
use LWP::UserAgent;
use URI::Escape;
use CGI;
use Mozilla::CA;

my $URL  = '';
my $MODE = '';
my $TAMPER_PROOF_SEAL;

# New
sub new {
    my $class = shift;
    my $self  = {};      # allocate new hash for object
    bless( $self, $class );

    # Sets account variable
    $self->{ACCOUNT_ID} = shift;
    $self->{SECRET_KEY} = shift;
    $self->{MODE} = shift;

    # return object
    return $self;
}

# calculates tamper proof seal based on api declared
sub calc_tps {
    my $self = shift;
    if ($self->{API} eq 'bpdailyreport2' ) {
        $self->{URL} = 'https://secure.bluepay.com/interfaces/bpdailyreport2';
        my $TAMPER_PROOF_DATA =
            ( $self->{SECRET_KEY}        || '' )
          . ( $self->{ACCOUNT_ID}        || '' )
          . ( $self->{REPORT_START_DATE} || '' )
          . ( $self->{REPORT_END_DATE}   || '' );
        $TAMPER_PROOF_SEAL = md5_hex $TAMPER_PROOF_DATA;
    }
    elsif ($self->{API} eq "stq") {
        $self->{URL} = 'https://secure.bluepay.com/interfaces/stq';
        my $TAMPER_PROOF_DATA =
            ( $self->{SECRET_KEY}        || '' )
          . ( $self->{ACCOUNT_ID}        || '' )
          . ( $self->{REPORT_START_DATE} || '' )
          . ( $self->{REPORT_END_DATE}   || '' );
        $TAMPER_PROOF_SEAL = md5_hex $TAMPER_PROOF_DATA;
    }    
    elsif ($self->{API} eq 'bp10emu' ) {
        #returns the remote host IP address
        my $q = CGI->new;
        $self->{REMOTE_IP} = $q->remote_addr(); 
        $self->{URL} = 'https://secure.bluepay.com/interfaces/bp10emu';
        $self->{MERCHANT} = $self->{ACCOUNT_ID};
        my $TAMPER_PROOF_DATA =
            ( $self->{SECRET_KEY}       || '' )
          . ( $self->{MERCHANT}         || '' )
          . ( $self->{TRANSACTION_TYPE} || '' )
          . ( $self->{AMOUNT}           || '' )
          . ( $self->{REBILLING}        || '' )
          . ( $self->{REB_FIRST_DATE}   || '' )
          . ( $self->{REB_EXPR}         || '' )
          . ( $self->{REB_CYCLES}       || '' )
          . ( $self->{REB_AMOUNT}       || '' )
          . ( $self->{RRNO}             || '' )
          . ( $self->{MODE}             || '' );
        $TAMPER_PROOF_SEAL = sha512_hex $TAMPER_PROOF_DATA;
        $self->{TPS_HASH_TYPE} = "SHA512";
    }
    elsif ($self->{API} eq 'bp20rebadmin' ) {
        $self->{URL} = 'https://secure.bluepay.com/interfaces/bp20rebadmin';
        my $TAMPER_PROOF_DATA =
            ( $self->{SECRET_KEY} || '' )
          . ( $self->{ACCOUNT_ID} || '' )
          . ( $self->{TRANS_TYPE} || '' )
          . ( $self->{REBILL_ID}  || '' );
        $TAMPER_PROOF_SEAL = md5_hex $TAMPER_PROOF_DATA;
    }
    return $TAMPER_PROOF_SEAL;
}

sub calc_trans_notify_tps {
    my $tpsString = shift;
    my $bp_stamp = md5_hex $tpsString;
    return $bp_stamp;
}

# Makes the API request and gets response
sub process {
    my $self = shift;
    # calculates tamper proof seal
    $TAMPER_PROOF_SEAL = $self->calc_tps();
    # Create request (encode)
    my $request =
        $self->{URL} 
        . "\?FIELDS="
        . "&TAMPER_PROOF_SEAL="
        . uri_escape( $TAMPER_PROOF_SEAL || '' );
    
    # converts the object's attributes into a query string for the api request
    while ( my ( $key, $value ) = each(%$self) ) {
        if ( $key eq 'SECRET_KEY' ) { next; }
        if ( $key eq 'URL' )        { next; }
        $request .= "&$key=" . uri_escape( $value || '' );
    }

    # prints the full api request url 
    # print "\n" . "request: "  . "\n" . $request . "\n \n";

    # Create Agent
    my $ua = new LWP::UserAgent;
    my $content;
    
    if ($self->{API} eq 'bp10emu' ) {
        my $req = new HTTP::Request 'POST', $self->{URL};
        $req->content($request);
        my $raw_response = $ua->request($req);
        my $response_string = $raw_response->header("Location");
        my @content_string  = split /[?]/, $response_string;
        my $content_string = $content_string[1];
        # use the parse response method to parse the raw response and assign response values
        $self->parse_response($content_string);
    }
    elsif ($self->{API} eq 'bpdailyreport2' ) {
        my $req = new HTTP::Request 'POST', $self->{URL};
        $req->content($request);
        my $raw_response = $ua->request($req);
        $content = $raw_response->content;
        $self->{response} = $content
    }
    elsif ($self->{API} eq 'stq' ) {
        my $req = new HTTP::Request 'POST', $self->{URL};
        $req->content($request);
        my $raw_response = $ua->request($req);
        $content = $raw_response->content;
        $self->parse_response($content);
        $self->{response} = $content;
    }
    elsif ($self->{API} eq 'bp20rebadmin' ){
        my $req = new HTTP::Request 'POST', $self->{URL};
        $req->content($request);
        my $raw_response = $ua->request($req);
        $content = $raw_response->content;
        $self->parse_response($content);
    }
}

# Parse Response string and assign response values to self.  (Used in process function)
sub parse_response {
    my $self = shift;
    my $response_string = shift;
     # create an array of values; split at the '&' symbol
     my @response_array = split( /&/, $response_string);
     # prints the array
     # print join(", ", @response_array); print "\n";

     # Iterates through array.  Assigns attributes to self for each of the key-values in response.  
    for my $el (@response_array) {
         # print $el; print "\n";
         my @array = split ( /=/, $el); 
         # print $key; print "\n";
         my $key = uri_unescape($array[0]);
         my $value = uri_unescape($array[1]);
        $self->{$key} = $value;
    }
}

# returns true if the transaction is successful
sub is_successful_response{
    my $self = shift;
    $self->{Result} eq "APPROVED" && $self->{MESSAGE} ne "DUPLICATE";
    # return 1
}

# Set CC information
sub set_cc_information {
    my $self = shift;
    my $params =  shift;
    $self->{PAYMENT_TYPE} = 'CREDIT'; 
    $self->{CC_NUM} = $params->{cc_number};
    $self->{CC_EXPIRES} = $params->{cc_expiration};
    $self->{CVCVV2} = $params->{cvv2}; 
}

# Sets payment information for a swiped credit card transaction
sub swipe {
    my $self = shift;
    my $track_data = shift;
    $self->{SWIPE} = $track_data;
}

# Set Customer Information
sub set_customer_information{
    my $self = shift;
    my $params =  shift;
    $self->{NAME1} = $params->{first_name};
    $self->{NAME2} = $params->{last_name};
    $self->{ADDR1} = $params->{address1};
    $self->{ADDR2} = $params->{address2};
    $self->{CITY} = $params->{city};
    $self->{STATE} = $params->{state};
    $self->{ZIPCODE} = $params->{zip_code};
    $self->{COUNTRY} = $params->{country};
    $self->{PHONE} = $params->{phone};
    $self->{EMAIL} = $params->{email};
}

# Set ACH Payment information 
sub set_ach_information{
    my $self = shift;
    my $params =  shift;
    $self->{PAYMENT_TYPE} = 'ACH';
    $self->{ACH_ROUTING} = $params->{ach_routing};
    $self->{ACH_ACCOUNT} = $params->{ach_account};
    $self->{ACH_ACCOUNT_TYPE} = $params->{ach_account_type};
    $self->{DOC_TYPE} = $params->{doc_type}; #optional
}

# Set Sale Transaction
sub sale {
    my $self = shift;
    my $params =  shift;
    $self->{TRANSACTION_TYPE} = 'SALE';
    $self->{API} = 'bp10emu'; 
    $self->{AMOUNT} = $params->{amount};
    $self->{RRNO} = $params->{trans_id}; #optional
}

# Set up an Auth
sub auth{
    my $self = shift;
    my $params =  shift;
    $self->{TRANSACTION_TYPE} = 'AUTH';
    $self->{AMOUNT} = $params->{amount};
    $self->{RRNO} = $params->{trans_id}; # optional
    $self->{API} = 'bp10emu'; 
 } 
# Capture an Auth
sub capture{
    my $self = shift;
    my $params =  shift;
    $self->{TRANSACTION_TYPE} = 'CAPTURE';
    $self->{AMOUNT} = $params->{amount};
    $self->{RRNO} = $params->{trans_id}; # optional
    $self->{API} = 'bp10emu'; 
}

# Refund
sub refund{
    my $self = shift;
    my $params =  shift;
    $self->{TRANSACTION_TYPE} = 'REFUND';
    $self->{AMOUNT} = $params->{amount};
    $self->{RRNO} = $params->{trans_id}; # optional
    $self->{API} = 'bp10emu'; 
}
# Void
sub void{
    my $self = shift;
    my $params =  shift;
    $self->{TRANSACTION_TYPE}  = 'VOID';
    $self->{AMOUNT} = $params->{amount};
    $self->{RRNO} = $params->{trans_id}; # optional
    $self->{API} = 'bp10emu'; 
}

# Set fields for a recurring payment
sub set_recurring_payment{
    my $self = shift;
    my $params =  shift;
    $self->{REBILLING} = '1';
    $self->{REB_FIRST_DATE} = $params->{reb_first_date};
    $self->{REB_EXPR} = $params->{reb_expr};
    $self->{REB_CYCLES} = $params->{reb_cycles};
    $self->{REB_AMOUNT} = $params->{reb_amount};
}
 
# Set fields to do an update on an existing rebilling cycle
sub update_rebill{
    my $self = shift;
    my $params =  shift;
    $self->{TRANS_TYPE} = "SET";
    $self->{REBILL_ID} = $params->{rebill_id};
    $self->{NEXT_DATE} = $params->{next_date};
    $self->{REB_EXPR} = $params->{reb_expr};
    $self->{REB_CYCLES} = $params->{reb_cycles};
    $self->{REB_AMOUNT} = $params->{reb_amount};
    $self->{NEXT_AMOUNT} = $params->{next_amount};
    $self->{TEMPLATE_ID} = $params->{template_id};
    $self->{API} = "bp20rebadmin";
}
# Set fields to cancel an existing rebilling cycle
sub cancel_rebilling_cycle{
    my $self = shift;
    my $rebill_id = shift;
    $self->{TRANS_TYPE} = "SET";
    $self->{STATUS} = "stopped";
    $self->{REBILL_ID} = $rebill_id;
    $self->{API} = "bp20rebadmin";
}
# Set fields to get the status of an existing rebilling cycle
sub get_rebilling_cycle_status{
    my $self = shift;
    my $rebill_id = shift;
    $self->{TRANS_TYPE} = "GET";
    $self->{REBILL_ID} = $rebill_id;
    $self->{API} = "bp20rebadmin";
}
# Gets a report on all transactions within a specified date range
sub get_transaction_report{
    my $self = shift;
    my $params =  shift;
    $self->{QUERY_BY_SETTLEMENT} = '0';
    $self->{REPORT_START_DATE} = $params->{report_start_date};
    $self->{REPORT_END_DATE} = $params->{report_end_date};
    $self->{QUERY_BY_HIERARCHY} = $params->{query_by_hierarchy};
    $self->{DO_NOT_ESCAPE} = $params->{do_not_escape}; # optional
    $self->{EXCLUDE_ERRORS} = $params->{exclude_errors}; # optional
    $self->{API} = "bpdailyreport2";
}

# Gets a report on all settled transactions within a specified date range
sub get_settled_transaction_report{
    my $self = shift;
    my $params =  shift;
    $self->{QUERY_BY_SETTLEMENT} = '1';
    $self->{REPORT_START_DATE} = $params->{report_start_date};
    $self->{REPORT_END_DATE} = $params->{report_end_date};
    $self->{QUERY_BY_HIERARCHY} = $params->{query_by_hierarchy};
    $self->{DO_NOT_ESCAPE} = $params->{do_not_escape}; # optional
    $self->{EXCLUDE_ERRORS} = $params->{exclude_errors}; # optional
    $self->{API} = "bpdailyreport2";
}

# Gets data on a specific transaction
sub get_single_transaction_query{
    my $self = shift;
    my $params =  shift;
    $self->{API} = "stq";    
    $self->{REPORT_START_DATE} = $params->{report_start_date};
    $self->{REPORT_END_DATE} = $params->{report_end_date};
    $self->{id} = $params->{transaction_id};
    $self->{EXCLUDE_ERRORS} = $params->{exclude_errors}; # optional
}

# Required arguments for generate_url:
  # merchant_name: Merchant name that will be displayed in the payment page.
  # return_url: Link to be displayed on the transacton results page. Usually the merchant's web site home page.
  # transaction_type: SALE/AUTH -- Whether the customer should be charged or only check for enough credit available.
  # accept_discover: Yes/No -- Yes for most US merchants. No for most Canadian merchants.
  # accept_amex: Yes/No -- Has an American Express merchant account been set up?
  # amount: The amount if the merchant is setting the initial amount.
  # protect_amount: Yes/No -- Should the amount be protected from changes by the tamperproof seal?
  # rebilling: Yes/No -- Should a recurring transaction be set up?
  # paymentTemplate: Select one of our payment form template IDs or your own customized template ID. If the customer should not be allowed to change the amount, add a 'D' to the end of the template ID. Example: 'mobileform01D'
      # mobileform01 -- Credit Card Only - White Vertical (mobile capable) 
      # default1v5 -- Credit Card Only - Gray Horizontal 
      # default7v5 -- Credit Card Only - Gray Horizontal Donation
      # default7v5R -- Credit Card Only - Gray Horizontal Donation with Recurring
      # default3v4 -- Credit Card Only - Blue Vertical with card swipe
      # mobileform02 -- Credit Card & ACH - White Vertical (mobile capable)
      # default8v5 -- Credit Card & ACH - Gray Horizontal Donation
      # default8v5R -- Credit Card & ACH - Gray Horizontal Donation with Recurring
      # mobileform03 -- ACH Only - White Vertical (mobile capable)
  # receiptTemplate: Select one of our receipt form template IDs, your own customized template ID, or "remote_url" if you have one.
      # mobileresult01 -- Default without signature line - White Responsive (mobile)
      # defaultres1 -- Default without signature line – Blue
      # V5results -- Default without signature line – Gray
      # V5Iresults -- Default without signature line – White
      # defaultres2 -- Default with signature line – Blue
      # remote_url - Use a remote URL
  # receipt_temp_remote_url: Your remote URL ** Only required if receipt_template = "remote_url".

  # Optional arguments for generate_url:
  # reb_protect: Yes/No -- Should the rebilling fields be protected by the tamperproof seal?
  # reb_amount: Amount that will be charged when a recurring transaction occurs.
  # reb_cycles: Number of times that the recurring transaction should occur. Not set if recurring transactions should continue until canceled.
  # reb_start_date: Date (yyyy-mm-dd) or period (x units) until the first recurring transaction should occur. Possible units are DAY, DAYS, WEEK, WEEKS, MONTH, MONTHS, YEAR or YEARS. (ex. 2016-04-01 or 1 MONTH)
  # reb_frequency: How often the recurring transaction should occur. Format is 'X UNITS'. Possible units are DAY, DAYS, WEEK, WEEKS, MONTH, MONTHS, YEAR or YEARS. (ex. 1 MONTH) 
  # custom_id: A merchant defined custom ID value.
  # protect_custom_id: Yes/No -- Should the Custom ID value be protected from change using the tamperproof seal?
  # custom_id2: A merchant defined custom ID 2 value.
  # protect_custom_id2: Yes/No -- Should the Custom ID 2 value be protected from change using the tamperproof seal?
   
sub generate_url{
    my $self = shift;
    my $params =  shift;
    $self->{DBA} = $params->{merchant_name}; 
    $self->{RETURN_URL} = $params->{return_url};  
    $self->{TRANSACTION_TYPE} = $params->{transaction_type};  
    $self->{DISCOVER_IMAGE} = $params->{accept_discover} =~ /^[yY]/ ? "discvr.gif" : "spacer.gif";
    $self->{AMEX_IMAGE} = $params->{accept_amex} =~ /^[yY]/ ? "amex.gif" : "spacer.gif";
    $self->{AMOUNT} = $params->{amount} || ''; 
    $self->{PROTECT_AMOUNT} = $params->{protect_amount} || "No";
    $self->{REBILLING} = $params->{rebilling}=~ /^[yY]/ ? "1" : "0";
    $self->{REB_PROTECT} = $params->{reb_protect} || 'Yes';
    $self->{REB_AMOUNT} = $params->{reb_amount} || '';
    $self->{REB_CYCLES} = $params->{reb_cycles} || '';
    $self->{REB_FIRST_DATE} = $params->{reb_start_date} || '';
    $self->{REB_EXPR} = $params->{reb_frequency} || '';
    $self->{CUSTOM_ID} = $params->{custom_id} || '';
    $self->{PROTECT_CUSTOM_ID} = $params->{protect_custom_id} || "No";
    $self->{CUSTOM_ID2} = $params->{custom_id2} || '';
    $self->{PROTECT_CUSTOM_ID2} = $params->{protect_custom_id2} || "No";
    $self->{SHPF_FORM_ID} = $params->{payment_template} || "mobileform01";
    $self->{RECEIPT_FORM_ID} = $params->{receipt_template} || "mobileresult01";
    $self->{REMOTE_URL} = $params->{receipt_temp_remote_url} || '';
    $self->{CARD_TYPES} = $self->set_card_types();
    $self->{RECEIPT_TPS_DEF} = 'SHPF_ACCOUNT_ID SHPF_FORM_ID RETURN_URL DBA AMEX_IMAGE DISCOVER_IMAGE SHPF_TPS_DEF';
    $self->{RECEIPT_TPS_STRING} = $self->set_receipt_tps_string();
    $self->{RECEIPT_TAMPER_PROOF_SEAL} = $self->calc_url_tps($self->{RECEIPT_TPS_STRING});
    $self->{RECEIPT_URL} = $self->set_receipt_url();
    $self->{BP10EMU_TPS_DEF} = $self->add_def_protected_status('MERCHANT APPROVED_URL DECLINED_URL MISSING_URL MODE TRANSACTION_TYPE TPS_DEF');
    $self->{BP10EMU_TPS_STRING} = $self->set_bp10emu_tps_string();
    $self->{BP10EMU_TAMPER_PROOF_SEAL} = $self->calc_url_tps($self->{BP10EMU_TPS_STRING});
    $self->{SHPF_TPS_DEF} = $self->add_def_protected_status('SHPF_FORM_ID SHPF_ACCOUNT_ID DBA TAMPER_PROOF_SEAL AMEX_IMAGE DISCOVER_IMAGE TPS_DEF SHPF_TPS_DEF');
    $self->{SHPF_TPS_STRING} = $self->set_shpf_tps_string();
    $self->{SHPF_TAMPER_PROOF_SEAL} = $self->calc_url_tps($self->{SHPF_TPS_STRING});
    return $self->calc_url_response();
}

# Sets the types of credit card images to use on the Simple Hosted Payment Form. Must be used with generate_url.
sub set_card_types{
    my $self = shift;
    my $CREDIT_CARDS = 'vi-mc';
    if ($self->{DISCOVER_IMAGE} eq 'discvr.gif') { $CREDIT_CARDS .= '-di'};
    if ($self->{AMEX_IMAGE} eq 'amex.gif') { $CREDIT_CARDS .= '-am'};
    return $CREDIT_CARDS;
}

# Sets the receipt Tamperproof Seal string. Must be used with generate_url.
sub set_receipt_tps_string{
    my $self = shift;
    return $self->{SECRET_KEY} . 
        $self->{ACCOUNT_ID} . 
        $self->{RECEIPT_FORM_ID} .
        $self->{RETURN_URL} .
        $self->{DBA} .
        $self->{AMEX_IMAGE} .
        $self->{DISCOVER_IMAGE} .
        $self->{RECEIPT_TPS_DEF};
}

# Sets the bp10emu string that will be used to create a Tamperproof Seal. Must be used with generate_url.
sub set_bp10emu_tps_string{
    my $self = shift;
    my $BP10EMU = 
        $self->{SECRET_KEY} .
        $self->{ACCOUNT_ID} .
        $self->{RECEIPT_URL} .
        $self->{RECEIPT_URL} .
        $self->{RECEIPT_URL} .
        $self->{MODE} .
        $self->{TRANSACTION_TYPE} .
        $self->{BP10EMU_TPS_DEF};
    return add_string_protected_status($self, $BP10EMU);
}

# Sets the Simple Hosted Payment Form string that will be used to create a Tamperproof Seal. Must be used with generate_url.
sub set_shpf_tps_string{
    my $self = shift;
    my $SHPF = 
        $self->{SECRET_KEY} .
        $self->{SHPF_FORM_ID} .
        $self->{ACCOUNT_ID} . 
        $self->{DBA} .
        $self->{BP10EMU_TAMPER_PROOF_SEAL} . 
        $self->{AMEX_IMAGE} .
        $self->{DISCOVER_IMAGE} .
        $self->{BP10EMU_TPS_DEF} .
        $self->{SHPF_TPS_DEF};
    return add_string_protected_status($self, $SHPF);
}

# Sets the receipt url or uses the remote url provided. Must be used with generate_url.
sub set_receipt_url{
    my $self = shift;
    if ($self->{RECEIPT_FORM_ID} eq 'remote_url') {
      return $self->{REMOTE_URL};
    }
    else {
      return 'https://secure.bluepay.com/interfaces/shpf?SHPF_FORM_ID=' . $self->{RECEIPT_FORM_ID} .
      '&SHPF_ACCOUNT_ID=' . $self->{ACCOUNT_ID} . 
      '&SHPF_TPS_DEF='    . $self->url_encode($self->{RECEIPT_TPS_DEF}) . 
      '&SHPF_TPS='        . $self->url_encode($self->{RECEIPT_TAMPER_PROOF_SEAL}) . 
      '&RETURN_URL='      . $self->url_encode($self->{RETURN_URL}) . 
      '&DBA='             . $self->url_encode($self->{DBA}) . 
      '&AMEX_IMAGE='      . $self->url_encode($self->{AMEX_IMAGE}) . 
      '&DISCOVER_IMAGE='  . $self->url_encode($self->{DISCOVER_IMAGE});
    }
  }

# Adds optional protected keys to a string. Must be used with generate_url.
sub add_def_protected_status{
    my $self = shift;
    my $string = shift;
    if ($self->{PROTECT_AMOUNT} eq 'Yes') {$string .= (' AMOUNT')};
    if ($self->{REB_PROTECT} eq 'Yes') {$string .= ' REBILLING REB_CYCLES REB_AMOUNT REB_EXPR REB_FIRST_DATE'};
    if ($self->{PROTECT_CUSTOM_ID} eq 'Yes') {$string .= ' CUSTOM_ID'};
    if ($self->{PROTECT_CUSTOM_ID2} eq'Yes') {$string .= ' CUSTOM_ID2'};
    return $string;
}

# Adds optional protected values to a string. Must be used with generate_url.
sub add_string_protected_status{
    my $self = shift;
    my $string = shift;
    if ($self->{PROTECT_AMOUNT} eq'Yes') {$string .= $self->{AMOUNT}};
    if ($self->{REB_PROTECT} eq 'Yes') {$string .= $self->{REBILLING} . $self->{REB_CYCLES} . $self->{REB_AMOUNT} . $self->{REB_EXPR} . $self->{REB_FIRST_DATE}};
    if ($self->{PROTECT_CUSTOM_ID} eq 'Yes') {$string .= $self->{CUSTOM_ID}};
    if ($self->{PROTECT_CUSTOM_ID2} eq 'Yes') {$string .= $self->{CUSTOM_ID2}};
    return $string;
}

# Encodes a string into a URL. Must be used with generate_url.
sub url_encode{
    my $self = shift;
    my $string = shift;
    my $encoded_string;
    foreach my $char (split //, $string){
        $char =~ s/([^A-Za-z0-9])/'%' . sprintf("%02X", ord($1))/eg;
        $encoded_string .= $char
    }
   return $encoded_string
}

# Generates a Tamperproof Seal for a url. Must be used with generate_url.
sub calc_url_tps{
    my $self = shift;
    my $tps_type = shift;
    return md5_hex $tps_type;
}

# Generates the final url for the Simple Hosted Payment Form. Must be used with generate_url.
sub calc_url_response{
    my $self = shift;
    return 'https://secure.bluepay.com/interfaces/shpf?'                                .
    'SHPF_FORM_ID='       . $self->url_encode    ($self->{SHPF_FORM_ID})                .
    '&SHPF_ACCOUNT_ID='   . $self->url_encode    ($self->{ACCOUNT_ID})                  .
    '&SHPF_TPS_DEF='      . $self->url_encode    ($self->{SHPF_TPS_DEF})                .
    '&SHPF_TPS='          . $self->url_encode    ($self->{SHPF_TAMPER_PROOF_SEAL})      .
    '&MODE='              . $self->url_encode    ($self->{MODE})                        .
    '&TRANSACTION_TYPE='  . $self->url_encode    ($self->{TRANSACTION_TYPE})            .
    '&DBA='               . $self->url_encode    ($self->{DBA})                         .
    '&AMOUNT='            . $self->url_encode    ($self->{AMOUNT})                      .
    '&TAMPER_PROOF_SEAL=' . $self->url_encode    ($self->{BP10EMU_TAMPER_PROOF_SEAL})   .
    '&CUSTOM_ID='         . $self->url_encode    ($self->{CUSTOM_ID})                   .
    '&CUSTOM_ID2='        . $self->url_encode    ($self->{CUSTOM_ID2})                  .
    '&REBILLING='         . $self->url_encode    ($self->{REBILLING})                   .
    '&REB_CYCLES='        . $self->url_encode    ($self->{REB_CYCLES})                  .
    '&REB_AMOUNT='        . $self->url_encode    ($self->{REB_AMOUNT})                  .
    '&REB_EXPR='          . $self->url_encode    ($self->{REB_EXPR})                    .
    '&REB_FIRST_DATE='    . $self->url_encode    ($self->{REB_FIRST_DATE})              .
    '&AMEX_IMAGE='        . $self->url_encode    ($self->{AMEX_IMAGE})                  .
    '&DISCOVER_IMAGE='    . $self->url_encode    ($self->{DISCOVER_IMAGE})              .
    '&REDIRECT_URL='      . $self->url_encode    ($self->{RECEIPT_URL})                 .
    '&TPS_DEF='           . $self->url_encode    ($self->{BP10EMU_TPS_DEF})             .
    '&CARD_TYPES='        . $self->url_encode    ($self->{CARD_TYPES});
}


# COMMENTS
=head1 MODULES

This script has some dependencies that need to be installed before it
can run.  You can use cpan to install the modules.  They are:
 - Crypt::Digest::SHA512
 - Digest::MD5
 - LWP::UserAgent
 - URI::Escape

=head1 AUTHOR

The BluePay::BluePayPayment perl module was written by Christopher Kois <ckois@bluepay.com> and modified
by Justin Slingerland <jslingerland@bluepay.com>.

=head1 COPYRIGHTS

    The BluePay::BluePay package is Copyright (c) January, 2013 by BluePay, Inc. 
    http://www.bluepay.com All rights reserved.  You may distribute this module under the terms 
    of GNU General Public License (GPL). 
    
Module Copyrights:
 - The Crypt::Digest::SHA512 module is Copyright (c) 2013-2015 DCIT, a.s. <http://www.dcit.cz> / Karel Miko
    Available at: http://http://search.cpan.org/~mik/CryptX-0.027_05/lib/Crypt/Digest/SHA512.pm
 - The Digest::MD5 module is Copyright (c) 1998-2003 Gisle Aas.
    Available at: http://search.cpan.org/~gaas/Digest-MD5-2.36/MD5.pm
 - The LWP::UserAgent module is Copyright (c) 1995-2008 Gisle Aas.
    Available at: http://search.cpan.org/~gaas/libwww-perl-5.812/lib/LWP/UserAgent.pm
 - The Crypt::SSLeay module is Copyright (c) 2006-2007 David Landgren.
    Available at: http://search.cpan.org/~dland/Crypt-SSLeay-0.57/SSLeay.pm
 - The URI::Escape module is Copyright (c) 1995-2004 Gisle Aas.
    Available at: http://search.cpan.org/~gaas/URI-1.36/URI/Escape.pm
                
NOTE: Each of these modules may have other dependencies.  The modules listed here are
the modules that BluePay::BluePayPayment specifically references.

=head1 SUPPORT/WARRANTY

BluePay::BluePayPayment is free Open Source software.  This code is Free.  You may use it, modify it, 
redistribute it, Post it on the bathroom wall, or whatever.  If you do make modifications that are 
useful, BluePay would love it if you donated them back to us!

=head1 KNOWN BUGS:

This is version 1.10 of BluePay::BluePayPayment.  There are currently no known bugs.

=head2 Post

Posts the data to the BluePay::BluePayPayment interface

=cut







1;
