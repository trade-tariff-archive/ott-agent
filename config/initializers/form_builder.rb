# Set GOV.UK Design System Form Builder as the application-wide default so that
# form_with / form_for helpers automatically expose govuk_text_area, govuk_submit,
# and other GOV.UK-specific builder methods without requiring the caller to pass
# builder: GOVUKDesignSystemFormBuilder::FormBuilder on each form.
ActionView::Base.default_form_builder = GOVUKDesignSystemFormBuilder::FormBuilder
