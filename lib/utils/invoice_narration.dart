import 'odoo_html_utils.dart';

/// An invoice's customer notes and its terms & conditions.
///
/// Odoo keeps both in one HTML field, `account.move.narration`, so the terms
/// are written as their own section under a "Terms & Conditions" heading and
/// split back out on that heading when the invoice is opened again.

/// Splits a `narration` value into the notes and terms the form edits.
///
/// A narration without the heading — one written in Odoo's web client, or
/// saved before the app wrote terms — is all notes.
({String notes, String terms}) splitInvoiceNarration(dynamic narration) {
  final lines = odooHtmlToText(narration).split('\n');
  final heading = lines.indexWhere(_isTermsHeading);
  if (heading == -1) return (notes: lines.join('\n').trim(), terms: '');
  return (
    notes: lines.take(heading).join('\n').trim(),
    terms: lines.skip(heading + 1).join('\n').trim(),
  );
}

bool _isTermsHeading(String line) {
  final normalized = line.trim().toLowerCase();
  return normalized == 'terms & conditions' ||
      normalized == 'terms & conditions:';
}

/// Builds the `narration` HTML for [notes] and [terms], keeping their line
/// breaks. Returns `''` when both are blank.
String joinInvoiceNarration(String notes, String terms) {
  final notesHtml = textToOdooHtml(notes);
  final termsHtml = textToOdooHtml(terms);
  if (termsHtml.isEmpty) return notesHtml;
  return '$notesHtml<p><strong>Terms &amp; Conditions</strong></p>$termsHtml';
}
