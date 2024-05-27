import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["burger", "menu"];
  static classes = ["active"]

  toggle() {
    const expanded = this.burgerTarget.getAttribute("aria-expanded") === "true";
    this.burgerTarget.setAttribute("aria-expanded", !expanded);
    this.burgerTarget.classList.toggle(this.activeClass);
    this.menuTarget.classList.toggle(this.activeClass);
  }
}
