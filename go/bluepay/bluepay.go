package bluepay

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
)

//TransactionResult contains the results of the post
type TransactionResult struct {
	TransID            string
	Status             string
	HTTPSuccess        bool
	HTTPResponseCode   int
	HTTPResponseString string
	Fields             map[string]string
	ReponseBody        []byte
}

// Transaction contains information necessary to run transaction
type Transaction struct {
	SecretKey string
	HashType  string
	Mode      string
	Fields    map[string]string
	TPSDef    []string
	Error     error
}

//APIURL is the API endpoint to connect to BluePay
var APIURL = "https://secure.bluepay.com/interfaces/bp20post"

// NewTransaction initializes and returns a Transaction struct
func NewTransaction(mode, accountID, secretKey string) Transaction {
	var t Transaction
	t.Fields = make(map[string]string)
	t.SecretKey = secretKey
	t.Fields["ACCOUNT_ID"] = accountID
	t.Fields["MODE"] = mode
	t.TPSDef = []string{"SECRET KEY", "ACCOUNT_ID", "TRANS_TYPE", "AMOUNT", "MASTER_ID", "NAME1", "PAYMENT_ACCOUNT"}
	return t
}

//SendTransaction sends the transaction to BluePay
func (t Transaction) SendTransaction() TransactionResult {

	t.calculateTps()
	qstr := url.Values{}
	for k, v := range t.Fields {
		qstr.Add(k, v)
	}
	log.Println(qstr)
	//sendStr := qstr.Encode()
	r, err := http.PostForm(APIURL, qstr)
	if err != nil {
		fmt.Println(err)
	}
	var res TransactionResult
	if r.ContentLength < 1 {
		res.ReponseBody = make([]byte, 8192)
	} else {
		res.ReponseBody = make([]byte, r.ContentLength)
	}
	read, err := r.Body.Read(res.ReponseBody)
	if err != nil {
		if err != io.EOF {
			panic("Problem with request")
		}
	}
	r.Body.Close()
	res.ReponseBody = res.ReponseBody[:read]
	res.HTTPResponseCode = r.StatusCode
	res.HTTPResponseString = r.Status
	res.Fields = make(map[string]string)
	resValues, err := url.ParseQuery(string(res.ReponseBody))
	fmt.Println(resValues)
	if err != nil {
		log.Println("Problem decoding response:", err)
		return res
	}
	for k, v := range resValues {
		res.Fields[k] = v[0]
	}
	return res
}

func (t Transaction) calculateTps() {
	md5str := t.SecretKey
	for _, v := range t.TPSDef {
		md5str += t.Fields[v]
	}
	hash := md5.Sum([]byte(md5str))
	t.Fields["TAMPER_PROOF_SEAL"] = hex.EncodeToString(hash[:])
}
