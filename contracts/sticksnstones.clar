;; data structures
;; ---------------
(define-non-fungible-token sticksnstones uint)
(define-map sticksnstones-data ((index uint)) ((owner (buff 80)) (asset-hash (buff 32)) (date uint)))
(define-map sale-data ((index uint)) ((sale-type uint) (increment-stx uint) (reserve-stx uint) (amount-stx uint)))
(define-map sticksnstones-lookup ((asset-hash (buff 32))) ((index uint)))

(define-data-var administrator principal 'STGPPTWJEZ2YAA7XMPVZ7EGKH0WX9F2DBNHTG5EY)
(define-data-var mint-price uint u10000)
(define-data-var base-token-uri (buff 100) 0x68747470733a2f2f6c6f6f70626f6d622e7269736964696f2e636f6d2f6170692f76312f6173736574732f)
(define-data-var mint-counter uint u0) ;; tracks nft creation

;; errors
(define-constant not-allowed u1)
(define-constant insufficient-funds u2)
(define-constant not-found u3)

;; public methods
;; --------------
(define-public (transfer-administrator (new-administrator principal))
    (begin
        (asserts! (is-eq (var-get administrator) tx-sender) (err not-allowed))
        (var-set administrator new-administrator)
        (ok true)
    )
)

(define-public (update-base-token-uri (new-base-token-uri (buff 100)))
    (begin 
        (asserts! (is-eq (var-get administrator) tx-sender) (err not-allowed))
        (var-set base-token-uri new-base-token-uri)
        (ok true)
    )
)

(define-public (update-mint-price (new-mint-price uint))
    (begin 
        (asserts! (is-eq (var-get administrator) tx-sender) (err not-allowed))
        (var-set mint-price new-mint-price)
        (ok true)
    )
)

(define-public (mint-token (asset-hash (buff 32)) (owner (buff 80)))
    (begin
        (asserts! (> (stx-get-balance tx-sender) (var-get mint-price)) (err insufficient-funds))
        (as-contract
            (stx-transfer? (var-get mint-price) tx-sender (var-get administrator))) ;; transfer stx if there is enough to pay for mint, otherwith throws an error
        (nft-mint? sticksnstones (var-get mint-counter) tx-sender)
        (map-insert sticksnstones-data ((index (var-get mint-counter))) ((owner owner) (asset-hash asset-hash) (date block-height)))
        (map-insert sticksnstones-lookup ((asset-hash asset-hash)) ((index (var-get mint-counter))))
        (print (var-get mint-counter))
        (var-set mint-counter (+ (var-get mint-counter) u1))
        (ok (var-get mint-counter))
    )
)

(define-public (set-sale-data (asset-hash (buff 32)) (sale-type uint) (increment-stx uint) (reserve-stx uint) (amount-stx uint))
    (match (map-get? sticksnstones-lookup ((asset-hash asset-hash)))
        myIndex
        (if 
            (try! (is-nft-owner (get index myIndex)))
            (ok (map-insert sale-data {index: (get index myIndex)} ((sale-type sale-type) (increment-stx increment-stx) (reserve-stx reserve-stx) (amount-stx amount-stx))))
            (err not-allowed)
        )
        (err not-found)
    )
)

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
    (map-get? sticksnstones-data ((index index))))

(define-read-only (get-index (asset-hash (buff 32)))
    (match (map-get? sticksnstones-lookup ((asset-hash asset-hash)))
        myIndex
        (ok (get index myIndex))
        (err not-found)
    )
)

(define-read-only (get-sale-data (index uint))
    (match (map-get? sale-data ((index index)))
        mySaleData
        (ok mySaleData)
        (err not-found)
    )
)

;; private methods
;; ---------------
(define-private (is-nft-owner (index uint))
    (if (is-eq (some tx-sender) (nft-get-owner? sticksnstones index))
        (ok true)
        (err not-allowed)
    )
)
