;; Title: StackCredit Protocol
;;
;; Summary:
;; A revolutionary decentralized lending ecosystem built on Bitcoin's 
;; Layer 2 that transforms traditional credit scoring through blockchain 
;; transparency and programmable trust mechanisms.
;;
;; Description:
;; StackCredit reimagines lending by creating an autonomous credit 
;; infrastructure where borrowers earn reputation through verifiable 
;; on-chain behavior. The protocol dynamically adjusts loan terms based 
;; on proven creditworthiness, enabling access to capital while securing 
;; lenders through intelligent collateral management. By leveraging 
;; Stacks' unique Bitcoin finality, users build portable credit scores 
;; that transcend traditional banking limitations, creating a truly 
;; decentralized financial identity backed by the world's most secure 
;; blockchain.
;;
;; PROTOCOL CONSTANTS

;; Protocol governance
(define-constant PROTOCOL-ADMIN tx-sender)

;; System error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-FUNDS (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-LOAN-NOT-EXISTS (err u103))
(define-constant ERR-LOAN-DEFAULTED (err u104))
(define-constant ERR-CREDIT-TOO-LOW (err u105))
(define-constant ERR-TOO-MANY-LOANS (err u106))
(define-constant ERR-PAYMENT-NOT-DUE (err u107))
(define-constant ERR-INVALID-DURATION (err u108))

;; Credit scoring parameters
(define-constant MIN-CREDIT-SCORE u300)     ;; Starting credit score
(define-constant MAX-CREDIT-SCORE u850)     ;; Excellent credit ceiling
(define-constant LOAN-ELIGIBILITY-SCORE u500) ;; Minimum for borrowing
(define-constant MAX-ACTIVE-LOANS u3)       ;; Concurrent loan limit

;; Lending parameters
(define-constant MAX-LOAN-DURATION u26280)  ;; ~6 months in blocks
(define-constant BASE-INTEREST-RATE u1200)  ;; 12% base APR
(define-constant MAX-COLLATERAL-RATIO u150) ;; 150% max collateral

;; DATA STRUCTURES

;; User credit profiles with comprehensive metrics
(define-map credit-profiles
  { user: principal }
  {
    credit-score: uint,
    total-borrowed: uint,
    total-repaid: uint,
    successful-loans: uint,
    defaulted-loans: uint,
    avg-repayment-time: uint,
    last-activity: uint,
    profile-created: uint
  }
)

;; Loan registry with detailed tracking
(define-map loan-registry
  { loan-id: uint }
  {
    borrower: principal,
    principal-amount: uint,
    collateral-locked: uint,
    maturity-block: uint,
    interest-rate: uint,
    total-repaid: uint,
    status: (string-ascii 16),
    created-at: uint
  }
)

;; User loan tracking for portfolio management
(define-map user-portfolios
  { borrower: principal }
  { active-loan-ids: (list 10 uint) }
)

;; PROTOCOL STATE

(define-data-var next-loan-id uint u1)
(define-data-var total-value-locked uint u0)
(define-data-var total-loans-issued uint u0)

;; CORE PROTOCOL FUNCTIONS

;; Initialize user credit profile
;; Creates a new credit identity on the Stacks blockchain
(define-public (create-credit-profile)
  (let ((user tx-sender))
    (asserts! (is-none (map-get? credit-profiles { user: user })) 
              ERR-UNAUTHORIZED)
    
    (map-set credit-profiles 
      { user: user }
      {
        credit-score: MIN-CREDIT-SCORE,
        total-borrowed: u0,
        total-repaid: u0,
        successful-loans: u0,
        defaulted-loans: u0,
        avg-repayment-time: u0,
        last-activity: stacks-block-height,
        profile-created: stacks-block-height
      })
    (ok true)
  )
)