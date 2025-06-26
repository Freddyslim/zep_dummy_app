import frappe
from frappe.utils.file_manager import save_file


def get_context(context):
    if frappe.request.method == "POST":
        data = frappe.form_dict
        file = frappe.request.files.get("attachment")
        doc = frappe.get_doc({
            "doctype": "Projektanfrage",
            "auftragsart": data.get("auftragsart"),
            "anrede": data.get("anrede"),
            "vorname": data.get("vorname"),
            "nachname": data.get("nachname"),
            "firma": data.get("firma"),
            "strasse": data.get("strasse"),
            "plz": data.get("plz"),
            "ort": data.get("ort"),
            "handynummer": data.get("handynummer"),
            "email": data.get("email"),
            "details": data.get("details"),
        })
        doc.insert(ignore_permissions=True)

        if file:
            file_doc = save_file(file.filename, file.read(), doc.doctype, doc.name)
            doc.attachment = file_doc.file_url
            doc.save(ignore_permissions=True)

        customer_name = f"{doc.vorname} {doc.nachname}".strip()
        if not frappe.db.exists("Customer", {"customer_name": customer_name}):
            customer = frappe.get_doc({
                "doctype": "Customer",
                "customer_name": customer_name,
                "customer_type": "Individual",
                "customer_group": "All Customer Groups",
                "territory": "All Territories",
                "mobile_no": doc.handynummer,
                "email_id": doc.email,
            })
            customer.insert(ignore_permissions=True)

        context.success = True
    return context

