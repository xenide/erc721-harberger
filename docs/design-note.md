## Aim

- To design an ERC721 token such that it ends up in the hands of the most productive owner of this asset. One way to achieve this is by enforcing a Harberger tax system where the owner self-declares `price` and ANYONE can buy it ANYTIME from him at that `price`.

## Principles

1. All contract interactions and calculations should benefit the system slightly to prevent value extraction/griefing.
2. NFTs can be bought at any time, in any state, whether it's compliant, in grace period, or delinquent.

## Design Decisions

1. **Taxes are pre-paid**
    - This design ensures that the system is solvent by default instead of always chasing after arrears and simplifies tax accrual.
    - Changing tax rates doesn't affect existing NFTs' delinquency. Once paid, it's good for `TAX_EPOCH_DURATION`.

2. **Tax currency is specified as an ERC20**
    - To simplify design, we only allow payments in ERC20. Just use WETH for native.
    - This is a conscious trade-off. While it does make the UX slightly worse (can't pay in native in 1 tx, need to `approve`), it reduces the attack surface of managing `receive` and `fallback` and standardizes all token interactions.
    - Probably this will be in a DAO-issued token to increase demand for it.

3. **Frequency of tax payments / declaration of value**
    - We define a global tax epoch (default set to 60 days).
        - As things/cycles in the crypto/blockchain world move fast, it's more appropriate to be shorter in duration (60 days) as opposed to, say, an annual declaration/payment.
    - Price stays the same unless updated (higher or lower) by the owner or decays by the reverse Dutch auction when being delinquent.

4. **Tax rate**
    - Global for simplicity.
    - **Considerations:**
        - Assume that it's set by a DAO/timelock.
        - Set too high: owners will declare lower than actual value.
        - Set too low: owners will declare higher than actual value.
    - Proceeds of sales will go to the seller, 100%.

5. **Tax Declaration + Payment Mechanism**
    - Owners call `setPrice` as a way to re-declare the value and pay the taxes atomically.
    - To the creator of the contract, this is an elegant solution combining the two activities which are semantically linked anyway.
        - This mirrors the fashion it is done for RWA, where the declaration and payment are done simultaneously.
    - Owners can always renew taxes at any point before the expiry, and the previous effective tax credits will roll over when declared at the same price.
    - If the new declared value is a lower than the previous declared value and very close in time to the previous declared value, the owner may lose some tax credits.
      - this is to prevent griefing 
    - This will lead to  the phenomenon that any price increases will be reflected immediately by the owners (as they don't lose any tax credit), while price decreases will happen closer to the end of the tax epoch so as not to lose any tax credit.  

6. **Grace Period for Non-Payment**
    - We define a grace period (default set to 1 day) beyond the end of the tax epoch.
    - Owner has to pay a flat penalty of the full grace period (1 day) worth of taxes.
    - This is to allow the owner to renew taxes without losing ownership of it.
        - During the grace period, if the NFT is bought, the owner still gets the proceeds of it.
        - Beyond the grace period, it goes into an auction, and the proceeds go to the contract/DAO.

7. **Delinquency**
    - Beyond the grace period, the NFT goes into delinquency and an auction.
    - **Reverse Dutch Auction:** prices go from 100% (listed price) to `MIN_NFT_PRICE` over the course of the tax epoch duration.
        - This mechanism is selected as the previous owner probably overpriced it. Therefore, allowing it to fall gradually until it's attractive to a buyer is sensible.
    - The DAO loses out on the taxes not collected from the end of the previous tax epoch to the point where it is sold but gets the proceeds of the sales.

8. **Fee Collection**
    - Proceeds (sale of NFTs + collected taxes) remain in the contract until being swept into a treasury/multi-sig contract.
    - Tax payments/purchases are frequent, and we can economize on transfers with the sweep.

9. **Inherited Functionality from OZ's ERC721**
    - `ownerOf`
    - `balanceOf`
    - `approve`
    - `setApprovalForAll`
    - `isApprovedForAll`
    - `getApproved`
    - **Overridden External ERC721 Functions:**
        - `transferFrom`
        - `safeTransferFrom`
    - **Internal ERC721 Functions Explicitly Used in Code:**
        - `_safeMint`
        - `_update`

## Potential Improvements

1. Introduce `setPrices` that accepts an array to allow batch management of NFTs.
2. Solution to the tax rate decrease edge case:
    - Ramping for effective rate.

## Assumptions

1. There is some economic value for owning this NFT to justify the tax:
    - e.g., grants privileges, discounts, right to use certain resources, etc.
