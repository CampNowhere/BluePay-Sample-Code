package bluepay

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"net/http"
	"net/url"
)

type TransactionResult struct {
	TransID string
	Status  string
}

// Transaction contains information necessary to run transaction
type Transaction struct {
	SecretKey string
	HashType  string
	Mode      string
	Fields    map[string]string
	TPSDef    []string
}

//APIURL is the API endpoint to connect to BluePay
var APIURL = "http://localhost:8080"

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
	//sendStr := qstr.Encode()
	r, err := http.PostForm(APIURL, qstr)
	if err != nil {
		fmt.Println(err)
	} else {
		fmt.Println(r)
	}
	var res TransactionResult
	res.TransID = "999000000002"
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
