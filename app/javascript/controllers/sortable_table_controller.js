import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sortable-table"
export default class extends Controller {
  static targets = ["table"]

  connect() {
    this.currentColumn = null
    this.currentDirection = "asc"
  }

  sort(event) {
    event.preventDefault()

    const header = event.currentTarget
    const columnIndex = header.cellIndex
    const columnType = header.dataset.type || "string"

    // Determine sort direction
    if (this.currentColumn === columnIndex) {
      this.currentDirection = this.currentDirection === "asc" ? "desc" : "asc"
    } else {
      this.currentDirection = "asc"
      this.currentColumn = columnIndex
    }

    // Update sort indicators
    this.updateSortIndicators(header)

    // Sort the table
    this.sortTable(columnIndex, columnType, this.currentDirection)
  }

  updateSortIndicators(activeHeader) {
    // Remove all existing sort indicators
    this.tableTarget.querySelectorAll("th i.bi-arrow-up, th i.bi-arrow-down").forEach(icon => {
      icon.remove()
    })

    // Add indicator to active column
    const icon = document.createElement("i")
    icon.className = this.currentDirection === "asc" ? "bi bi-arrow-up ms-1" : "bi bi-arrow-down ms-1"
    activeHeader.appendChild(icon)
  }

  sortTable(columnIndex, columnType, direction) {
    const tbody = this.tableTarget.querySelector("tbody")
    const rows = Array.from(tbody.querySelectorAll("tr"))

    // Skip if no data rows
    if (rows.length === 0 || rows[0].cells.length <= columnIndex) {
      return
    }

    const sortedRows = rows.sort((a, b) => {
      const aValue = this.getCellValue(a, columnIndex, columnType)
      const bValue = this.getCellValue(b, columnIndex, columnType)

      // Handle null/undefined values
      if (aValue === null || aValue === undefined || aValue === "") {
        return direction === "asc" ? 1 : -1
      }
      if (bValue === null || bValue === undefined || bValue === "") {
        return direction === "asc" ? -1 : 1
      }

      let comparison = 0

      if (columnType === "number") {
        comparison = aValue - bValue
      } else {
        comparison = aValue.toString().localeCompare(bValue.toString())
      }

      return direction === "asc" ? comparison : -comparison
    })

    // Reorder rows in DOM
    sortedRows.forEach(row => tbody.appendChild(row))

    // Update row numbers
    this.updateRowNumbers()
  }

  getCellValue(row, columnIndex, columnType) {
    const cell = row.cells[columnIndex]
    if (!cell) return null

    const text = cell.textContent.trim()

    if (columnType === "number") {
      // Remove % sign and other non-numeric characters except . and -
      const cleaned = text.replace(/[^0-9.-]/g, "")
      const parsed = parseFloat(cleaned)
      return isNaN(parsed) ? null : parsed
    }

    return text
  }

  updateRowNumbers() {
    const tbody = this.tableTarget.querySelector("tbody")
    const rows = tbody.querySelectorAll("tr")

    rows.forEach((row, index) => {
      const firstCell = row.cells[0]
      if (firstCell) {
        firstCell.textContent = index + 1
      }
    })
  }
}
