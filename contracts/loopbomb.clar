;; data structures
;; ---------------
(define-non-fungible-token loopbomb uint)
(define-map loopbomb-data ((index uint)) ((owner (buff 80)) (asset-hash (buff 32)) (date uint)))
(define-map loopbomb-lookup ((asset-hash (buff 32))) ((index uint)))

(define-data-var administrator principal 'STGPPTWJEZ2YAA7XMPVZ7EGKH0WX9F2DBNHTG5EY)
(define-data-var mint-price uint u10000)
(define-data-var base-token-uri (buff 100) 0x68747470733a2f2f6c6f6f70626f6d622e7269736964696f2e636f6d2f6170692f76312f6173736574732f)
(define-data-var mint-counter uint u0) ;; tracks nft creation

;; public methods
;; --------------
(define-public (transfer-administrator (new-administrator principal))
    (begin
        (asserts! (is-eq (var-get administrator) tx-sender) (err 1))
        (var-set administrator new-administrator)
        (ok true)))

(define-public (update-base-token-uri (new-base-token-uri (buff 100)))
    (begin 
        (asserts! (is-eq (var-get administrator) tx-sender) (err 1))
        (var-set base-token-uri new-base-token-uri)
        (ok true)))

(define-public (update-mint-price (new-mint-price uint))
    (begin 
        (asserts! (is-eq (var-get administrator) tx-sender) (err 1))
        (var-set mint-price new-mint-price)
        (ok true)))

(define-public (mint-token (asset-hash (buff 32)) (owner (buff 80)))
    (begin 
        (asserts! (> (stx-get-balance tx-sender) (var-get mint-price)) (err 2))
        (as-contract
            (stx-transfer? (var-get mint-price) tx-sender (var-get administrator))) ;; transfer stx if there is enough to pay for mint, otherwith throws an error
        (nft-mint? loopbomb (var-get mint-counter) tx-sender)
        (map-insert loopbomb-data ((index (var-get mint-counter))) ((owner owner) (asset-hash asset-hash) (date block-height)))
        (map-insert loopbomb-lookup ((asset-hash asset-hash)) ((index (var-get mint-counter))))
        (var-set mint-counter (+ (var-get mint-counter) u1))
        (ok (var-get mint-counter))))

;; read only methods
;; ---------------
(define-read-only (get-administrator)
    (var-get administrator))

(define-read-only (is-administrator)
    (ok (is-eq (var-get administrator) tx-sender)))

(define-read-only (get-base-token-uri)
    (var-get base-token-uri))

(define-read-only (get-mint-counter)
  (ok (var-get mint-counter))
)

(define-read-only (get-mint-price)
    (var-get mint-price))

(define-read-only (get-token-info (index uint))
    (map-get? loopbomb-data ((index index))))

(define-read-only (get-index (asset-hash (buff 32)))
    (map-get? loopbomb-lookup ((asset-hash asset-hash))))

;; private methods
;; ---------------

