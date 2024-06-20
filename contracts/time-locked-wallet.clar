
;; title: time-locked-wallet
;; version: 1.0.0
;; summary: The block height can be used to perform actions over time. If you know the average block time, then you can calculate roughly how many blocks will be mined in a specific time frame
;; description: We will use this concept to create a wallet contract that unlocks at a specific block height. Such a contract can be useful if you want to bestow tokens to someone after a certain time period

;; Features
;; Instead of starting to code straight away, 
;; let us take a moment to consider the features we want to have.

;; A user can deploy the time-locked wallet contract.
;; Then, the user specifies a block height at which 
;; the wallet unlocks and a beneficiary.
;; Anyone, not just the contract deployer, can send tokens to the contract.
;; The beneficiary can claim the tokens once the specified block height is reached.
;; Additionally, the beneficiary can transfer the right to claim the wallet 
;; to a different principal. (For whatever reason.)

;; With the above in mind, the contract will thus feature the following public functions:

;; lock, takes the principal, unlock height, and an initial deposit amount.
;; claim, transfers the tokens to the tx-sender if and only if the unlock height has been reached and the tx-sender is equal to the beneficiary.
;; bestow, allows the beneficiary to transfer the right to claim the wallet.

;; traits
;;

;; token definitions
;; 

;; constants
;; owner
(define-constant contract-owner tx-sender)

;; errors
(define-constant err-owner-only (err u100))
(define-constant err-already-locked (err u101))
(define-constant err-unlock-in-past (err u102))
(define-constant err-no-value (err u103))
(define-constant err-beneficiary-only (err u104))
(define-constant err-unlock-height-not-reached (err u105))

;; data vars
(define-data-var beneficiary (optional principal) none)
(define-data-var unlock-height uint u0)

;; data maps
;;

;; public functions
;; The lock function does nothing more than transferring some 
;; tokens from the tx-sender to itself and setting the two variables.
;; However, we must not forget to check if the proper conditions
;; are set. Specifically:
(define-public (lock (new-beneficiary principal) (unlock-at uint) (amount uint)) 
  (begin 
    (asserts! (restricted tx-sender) err-owner-only)
    (asserts! (is-none (var-get beneficiary)) err-already-locked)
    (asserts! (> unlock-at block-height) err-unlock-in-past)
    ;; The (as-contract tx-sender) part gives us the principal of the contract.
    (try! (stx-transfer?  amount tx-sender (as-contract tx-sender)))
    (var-set beneficiary (some new-beneficiary))
    (var-set unlock-height unlock-at)
    (ok true)
  )
)

;; The bestow function will be straightforward. 
;; It checks if the tx-sender is the current beneficiary, 
;; and if so, will update the beneficiary to the passed principal. 
;; One side-note to keep in mind is that the principal is stored 
;; as an (optional principal). We thus need to wrap the tx-sender
;; in a (some ...) before we do the comparison.
(define-public (bestow (new-beneficiary principal)) 
  (begin  
     (asserts! (check tx-sender) err-beneficiary-only)
     (var-set beneficiary (some new-beneficiary))
     (ok true)
  )
)

;; claim function should check if both the tx-sender is the 
;; beneficiary and that the unlock height has been reached.
(define-public (claim) 
  (begin 
     (asserts! (check tx-sender) err-beneficiary-only)
     (asserts! (>= block-height (var-get unlock-height)) err-unlock-height-not-reached)
     ;; we didin't ok response here because stx-transfer returns a response.
     (as-contract 
       (stx-transfer? 
        (stx-get-balance tx-sender)
        tx-sender
        (unwrap-panic (var-get beneficiary))
        )
     )
  )
)


;; read only functions
;;

;; private functions
(define-private (restricted (caller principal)) 
  (is-eq caller contract-owner)
)

(define-private (check (caller principal)) 
  (is-eq (some caller) (var-get beneficiary))
)
