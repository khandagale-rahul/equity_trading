// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "admin_lte"
import "adminlte_turbo"
import "@popperjs/core"
import "bootstrap"

// Select2 Initialization for multi-select dropdowns
function initializeSelect2() {
  // Check if jQuery and Select2 are available
  if (typeof $ === 'undefined' || typeof $.fn.select2 === 'undefined') {
    return;
  }

  // Destroy existing Select2 instances to prevent duplicates
  $('.select2').each(function() {
    if ($(this).data('select2')) {
      $(this).select2('destroy');
    }
  });

  // Initialize Select2 with Bootstrap 5 theme
  $('.select2').select2({
    theme: 'bootstrap-5',
    width: '100%',
    placeholder: 'Search and select instruments...',
    allowClear: true,
    closeOnSelect: false,
    selectionCssClass: 'select2-selection--multiple-custom'
  });
}

// Initialize on DOMContentLoaded
document.addEventListener('DOMContentLoaded', function() {
  initializeSelect2();
});

// Re-initialize on Turbo navigation
document.addEventListener('turbo:load', function() {
  initializeSelect2();
});

// Re-initialize after form render (handles 422 errors)
document.addEventListener('turbo:render', function() {
  initializeSelect2();
});

// Clean up Select2 before Turbo caches the page
document.addEventListener('turbo:before-cache', function() {
  if (typeof $ !== 'undefined' && typeof $.fn.select2 !== 'undefined') {
    $('.select2').each(function() {
      if ($(this).data('select2')) {
        $(this).select2('destroy');
      }
    });
  }
});
