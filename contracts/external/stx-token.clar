;;;;;;;;;;;;;;;;;;;;; SIP 010 ;;;;;;;;;;;;;;;;;;;;;;
(impl-trait .sip-010-trait-ft-standard.sip-010-trait)

;; Defines the wrapped STX token according to the SIP-010 Standard
(define-data-var token-uri (string-utf8 256) u"")

;; errors
(define-constant ERR_NOT_AUTHORIZED u14401)

;; ---------------------------------------------------------
;; SIP-10 Functions
;; ---------------------------------------------------------

(define-read-only (get-total-supply)
  (ok u0)
)

(define-read-only (get-name)
  (ok "Unwrapped STX Token")
)

(define-read-only (get-symbol)
  (ok "unwSTX")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (account principal))
  (ok u0)
)

(define-read-only (get-token-uri)
  (ok (some (var-get token-uri)))
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_NOT_AUTHORIZED))

    (match (stx-transfer? amount sender recipient)
      response (begin
        (print memo)
        (ok response)
      )
      error (err error)
    )
  )
)