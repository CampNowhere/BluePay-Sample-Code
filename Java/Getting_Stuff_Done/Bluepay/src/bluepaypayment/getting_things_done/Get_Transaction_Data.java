package bluepaypayment.getting_things_done;

import bluepaypayment.BluePayPayment_BP10Emu;

 /**
* BluePay Java Sample code.
*
* This code sample runs a report that grabs data from the
* BluePay gateway based on certain criteria. See comments below
* on the details of the report.
* If using TEST mode, only TEST transactions will be returned.
*/



public class Get_Transaction_Data {

	  public static void main(String[] args) {
	     
	    String ACCOUNT_ID = "100221257489";
	    String SECRET_KEY = "YCBJNEUEKNINP5PWEH1HRQDSQHYANPM/";
	    String MODE = "TEST";
	     
	    // Merchant's Account ID
	        // Merchant's Secret Key
	        // Transaction Mode: TEST (can also be LIVE)
	    BluePayPayment_BP10Emu report = new BluePayPayment_BP10Emu(
	        ACCOUNT_ID,
	        SECRET_KEY,
	        MODE);
	     
	        // Report Start Date: Jan. 1, 2013
	        // Report End Date: Jan. 15, 2013
	        // Also search subaccounts? Yes
	        // Output response without commas? Yes
	        // Do not include errored transactions? Yes
	    report.getTransactionReport(
	        "2013-01-01",
	        "2013-01-15",
	        "1",
	        "1",
	        "1");
	    try {
	      report.process();
	      // Outputs response from BluePay gateway
	      System.out.println(report.getResponse());
	    } catch (Exception ex) {
	      System.out.println("Exception: " + ex.toString());
	      System.exit(1);
	    }
	  }
	}