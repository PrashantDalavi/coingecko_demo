document.addEventListener("DOMContentLoaded", () => {
  const tracker = document.querySelector("[data-crypto-price-tracker]")

  if (!tracker) {
    return
  }

  const coinSelect = tracker.querySelector("[data-crypto-price-select]")
  const coinName = tracker.querySelector("[data-crypto-price-name]")
  const priceValue = tracker.querySelector("[data-crypto-price-value]")
  const statusText = tracker.querySelector("[data-crypto-price-status]")

  const formatUsd = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 6
  })

  const selectedCoinName = () => {
    return coinSelect.selectedOptions[0].dataset.name
  }

  const fetchPrice = async () => {
    const coinId = coinSelect.value
    const url = new URL("/crypto_price", window.location.origin)

    url.searchParams.set("crypto_id", coinId)

    coinName.textContent = selectedCoinName()
    priceValue.textContent = "Loading..."
    statusText.textContent = "Fetching latest price..."
    statusText.classList.remove("is-error")

    try {
      const response = await fetch(url, { headers: { accept: "application/json" } })
      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || "Price request failed")
      }

      const price = data.price

      if (typeof price !== "number") {
        throw new Error("Price unavailable")
      }

      priceValue.textContent = formatUsd.format(price)
      coinName.textContent = data.name
      statusText.textContent = `Updated ${new Date(data.updated_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`
    } catch (error) {
      priceValue.textContent = "--"
      statusText.textContent = error.message
      statusText.classList.add("is-error")
    }
  }

  coinSelect.addEventListener("change", fetchPrice)
  fetchPrice()
  window.setInterval(fetchPrice, 60000)
})
