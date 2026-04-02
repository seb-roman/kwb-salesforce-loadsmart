import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLoads from '@salesforce/apex/ShipperLoadListController.getLoads';
import getStatusOptions from '@salesforce/apex/ShipperLoadListController.getStatusOptions';
import getLoadTypeOptions from '@salesforce/apex/ShipperLoadListController.getLoadTypeOptions';

export default class ShipperLoadList extends NavigationMixin(LightningElement) {
    @track loads = [];
    @track statusOptions = [];
    @track loadTypeOptions = [];
    @track isLoading = false;
    @track totalRecords = 0;
    @track pageNumber = 1;
    @track pageSize = 25;
    @track totalPages = 1;

    // Filter values
    @track statusFilter = 'All';
    @track dateFromFilter = '';
    @track dateToFilter = '';
    @track loadTypeFilter = 'All';
    @track isEmptyList = false;
    
    // Debounce timer for filter changes
    filterTimeout;

    columns = [
        { label: 'Load #', fieldName: 'Name', type: 'text', sortable: true },
        { label: 'Pickup City', fieldName: 'Pickup_City__c', type: 'text' },
        { label: 'Delivery City', fieldName: 'Delivery_City__c', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text', cellAttributes: { class: { fieldName: 'statusClass' } } },
        { label: 'ETA', fieldName: 'Estimated_Delivery__c', type: 'date' },
        { label: 'Rate', fieldName: 'Shipper_Rate__c', type: 'currency' },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'View Details', name: 'view_details' },
                    { label: 'Download BOL', name: 'download_bol' },
                    { label: 'Download POD', name: 'download_pod' }
                ]
            }
        }
    ];

    @wire(getStatusOptions)
    wiredStatusOptions({ error, data }) {
        if (data) {
            this.statusOptions = [{ label: 'All', value: 'All' }, ...data.map(s => ({ label: s, value: s }))];
        } else if (error) {
            console.error('Error loading status options:', error);
        }
    }

    @wire(getLoadTypeOptions)
    wiredLoadTypeOptions({ error, data }) {
        if (data) {
            this.loadTypeOptions = [{ label: 'All', value: 'All' }, ...data.map(t => ({ label: t, value: t }))];
        } else if (error) {
            console.error('Error loading load type options:', error);
        }
    }

    connectedCallback() {
        this.loadLoads();
    }

    loadLoads() {
        this.isLoading = true;
        getLoads({
            statusFilter: this.statusFilter,
            dateFrom: this.dateFromFilter,
            dateTo: this.dateToFilter,
            loadType: this.loadTypeFilter,
            pageNumber: this.pageNumber,
            pageSize: this.pageSize
        })
        .then(result => {
            this.loads = result.loads.map(load => ({
                ...load,
                statusClass: this.getStatusClass(load.Status__c)
            }));
            this.totalRecords = result.totalRecords;
            this.totalPages = result.totalPages;
            this.isEmptyList = result.loads.length === 0;
            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error loading loads:', error);
            this.showError('Error loading loads. Please try again.');
            this.isLoading = false;
        });
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.detail.value;
        this.pageNumber = 1;
        this.debounceLoadLoads();
    }

    handleDateFromChange(event) {
        this.dateFromFilter = event.detail.value;
        this.pageNumber = 1;
        this.debounceLoadLoads();
    }

    handleDateToChange(event) {
        this.dateToFilter = event.detail.value;
        this.pageNumber = 1;
        this.debounceLoadLoads();
    }

    handleLoadTypeChange(event) {
        this.loadTypeFilter = event.detail.value;
        this.pageNumber = 1;
        this.debounceLoadLoads();
    }

    /**
     * Debounce filter changes to avoid spam loading
     * Wait 500ms after last filter change before loading
     */
    debounceLoadLoads() {
        clearTimeout(this.filterTimeout);
        this.filterTimeout = setTimeout(() => {
            this.loadLoads();
        }, 500);
    }

    /**
     * Handle row action button click
     * Note: Using inline buttons instead of lightning-datatable row actions for better control
     */
    handleViewDetails(event) {
        const loadId = event.currentTarget.dataset.loadId;
        this.navigateToLoadDetail(loadId);
    }

    /**
     * Navigate to load detail page using NavigationMixin
     * Works in Salesforce community portals and orgs
     */
    navigateToLoadDetail(loadId) {
        // Option 1: Navigate to record view (if load detail uses standard record page)
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: loadId,
                actionName: 'view'
            }
        });
        
        // Option 2: For community portal, use named page (commented out - uncomment if using community)
        // this[NavigationMixin.Navigate]({
        //     type: 'comm__namedPage',
        //     attributes: {
        //         name: 'load_detail'
        //     },
        //     state: {
        //         c__loadId: loadId
        //     }
        // });
    }

    downloadDocument(docType, loadId) {
        this.showNotification('Download', `${docType} download will be processed`);
    }

    handlePreviousPage() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.loadLoads();
        }
    }

    handleNextPage() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.loadLoads();
        }
    }

    getStatusClass(status) {
        const classMap = {
            'Delivered': 'slds-text-color_success',
            'In Transit': 'slds-text-color_default',
            'At Risk': 'slds-text-color_warning',
            'Late': 'slds-text-color_error',
            'Posted': 'slds-text-color_default',
            'Assigned': 'slds-text-color_default'
        };
        return classMap[status] || 'slds-text-color_default';
    }

    showError(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error'
            })
        );
    }

    showNotification(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: 'info'
            })
        );
    }

    get pageInfo() {
        return `Page ${this.pageNumber} of ${this.totalPages} (${this.totalRecords} total)`;
    }

    get canPrevious() {
        return this.pageNumber > 1;
    }

    get canNext() {
        return this.pageNumber < this.totalPages;
    }
}
