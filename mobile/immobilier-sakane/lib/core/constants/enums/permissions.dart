/// Tous les droits connus de l'application.
///
/// Chaque valeur porte le code exact utilisé par le serveur
/// (catalogue des droits). L'administrateur a tous les droits.
enum AppPermission {
  // Immobilier
  viewProperties('view_properties'),
  createProperty('create_property'),
  updateProperty('update_property'),
  deleteProperty('delete_property'),
  shareProperty('share_property'),
  viewAvailableProperties('view_available_properties'),
  viewReservedProperties('view_reserved_properties'),
  viewCleaningProperties('view_cleaning_properties'),
  viewTodayCheckouts('view_today_checkouts'),
  confirmCheckin('confirm_checkin'),
  confirmCheckout('confirm_checkout'),
  startCleaning('start_cleaning'),
  finishCleaning('finish_cleaning'),
  returnToCleaning('return_to_cleaning'),
  viewDeactivatedProperties('view_deactivated_properties'),
  deactivateProperty('deactivate_property'),
  reactivateProperty('reactivate_property'),
  createFolder('create_folder'), // Alwed seulement
  updateFolder('update_folder'), // Alwed seulement
  deleteFolder('delete_folder'), // Alwed seulement
  assignFolderAgents('assign_folder_agents'), // Alwed seulement
  viewContract('view_contract'),
  createContract('create_contract'),
  viewReports('view_reports'),
  createReport('create_report'),
  // Réservations
  viewReservations('view_reservations'),
  exportReservations('export_reservations'),
  createReservation('create_reservation'),
  extendReservation('extend_reservation'),
  reduceReservation('reduce_reservation'),
  updateReservationPrice('update_reservation_price'),
  deleteReservation('delete_reservation'),
  viewReservationTrash('view_reservation_trash'),
  restoreReservation('restore_reservation'),
  viewInvoice('view_invoice'),
  applyInvoice('apply_invoice'),
  sendInvoice('send_invoice'),
  shareContractSyndic('share_contract_syndic'),
  setDefaultHours('set_default_hours'),
  // Calendrier
  viewCalendar('view_calendar'),
  updateNightPrices('update_night_prices'),
  blockDates('block_dates'),
  unblockDates('unblock_dates'),
  // Airbnb
  viewAirbnb('view_airbnb'),
  linkAirbnb('link_airbnb'),
  syncAirbnb('sync_airbnb'),
  // Clients
  viewClients('view_clients'),
  createClient('create_client'),
  updateClient('update_client'),
  deleteClient('delete_client'),
  blacklistClient('blacklist_client'),
  // Propriétaires
  viewOwners('view_owners'),
  createOwner('create_owner'),
  updateOwner('update_owner'),
  deleteOwner('delete_owner'),
  manageOwnerContracts('manage_owner_contracts'),
  // Charges
  viewCharges('view_charges'),
  createCharge('create_charge'),
  validateCharge('validate_charge'),
  cancelCharge('cancel_charge'),
  deleteCharge('delete_charge'),
  viewCancelledCharges('view_cancelled_charges'),
  viewProgramedCharges('view_programed_charges'),
  createProgramedCharge('create_programed_charge'),
  updateProgramedCharge('update_programed_charge'),
  deleteProgramedCharge('delete_programed_charge'),
  receiveChargeNotifications('receive_charge_notifications'),
  // Réclamations
  viewReclamations('view_reclamations'),
  createReclamation('create_reclamation'),
  closeReclamation('close_reclamation'),
  // Caisse
  viewOwnCashbox('view_own_cashbox'),
  cashIn('cash_in'),
  cashContribution('cash_contribution'),
  cashExpense('cash_expense'),
  cashTransfer('cash_transfer'),
  confirmCashTransfer('confirm_cash_transfer'),
  closeCashbox('close_cashbox'),
  viewCashboxHistory('view_cashbox_history'),
  viewAllCashboxes('view_all_cashboxes'),
  freeCashMovement('free_cash_movement'),
  emptyCashbox('empty_cashbox'),
  viewAirbnbCashbox('view_airbnb_cashbox'),
  transferAirbnbCashbox('transfer_airbnb_cashbox'),
  // Statistiques
  viewStats('view_stats'),
  downloadStatsReport('download_stats_report'),
  // Utilisateurs
  viewUsers('view_users'),
  createUser('create_user'),
  updateUser('update_user'),
  deleteUser('delete_user'),
  manageUserFolders('manage_user_folders'), // Alwed seulement
  // Réception WhatsApp
  manageOwnWhatsapp('manage_own_whatsapp'),
  manageTeamWhatsapp('manage_team_whatsapp'),
  // Plateforme
  viewAnnounces('view_announces'),
  activateAnnounce('activate_announce'),
  cancelAnnounce('cancel_announce'),
  viewSlider('view_slider'),
  createSlider('create_slider'),
  activateSlider('activate_slider'),
  // Campagnes WhatsApp
  viewCampaigns('view_campaigns'),
  createCampaign('create_campaign'),
  manageCampaign('manage_campaign'),
  deleteCampaign('delete_campaign'),
  manageCampaignNumber('manage_campaign_number'),
  // Modèles de messages
  viewMessageTemplates('view_message_templates'),
  updateMessageTemplates('update_message_templates'),
  manageReminders('manage_reminders'),
  // Syndics
  viewSyndics('view_syndics'),
  createSyndic('create_syndic'),
  updateSyndic('update_syndic'),
  deleteSyndic('delete_syndic'),
  viewSyndicHistory('view_syndic_history'),
  resendSyndicContract('resend_syndic_contract'),
  // Location longue durée
  viewLeases('view_leases'), // Alwed seulement
  createLease('create_lease'), // Alwed seulement
  updateLease('update_lease'), // Alwed seulement
  endLease('end_lease'), // Alwed seulement
  deleteLease('delete_lease'), // Alwed seulement
  collectRent('collect_rent'), // Alwed seulement
  // Vente
  viewSales('view_sales'), // Alwed seulement
  updateSaleStatus('update_sale_status'), // Alwed seulement
  createMandate('create_mandate'), // Alwed seulement
  updateMandate('update_mandate'), // Alwed seulement
  signMandate('sign_mandate'), // Alwed seulement
  deleteMandate('delete_mandate'), // Alwed seulement
  createVisit('create_visit'), // Alwed seulement
  signVisit('sign_visit'), // Alwed seulement
  deleteVisit('delete_visit'), // Alwed seulement
  // Exports
  exportData('export_data'),
  // Administration
  managePermissions('manage_permissions');

  const AppPermission(this.code);

  /// Code du droit côté serveur.
  final String code;
}
