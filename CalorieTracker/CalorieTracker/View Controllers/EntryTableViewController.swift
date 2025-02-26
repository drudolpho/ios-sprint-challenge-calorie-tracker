//
//  EntryTableViewController.swift
//  CalorieTracker
//
//  Created by Dennis Rudolph on 12/20/19.
//  Copyright © 2019 Lambda School. All rights reserved.

import UIKit
import SwiftChart
import CoreData

class EntryTableViewController: UITableViewController {

    @IBOutlet weak var chart: Chart!

    var data: [Double] = []
    let notificationCenter = NotificationCenter.default

    var series: ChartSeries {
        ChartSeries(data)
    }

    let dateFormatter = DateFormatter()

    @IBAction func addButtonTapped(_ sender: UIBarButtonItem) {

        let alert = UIAlertController(title: "Add Calorie Intake", message: "Enter the amount of calories in the field", preferredStyle: .alert)
        alert.addTextField()

        alert.addAction(UIAlertAction(title: "Submit", style: .default, handler: { _ in
            guard let calorieString = alert.textFields![0].text, !calorieString.isEmpty, let calorieDouble = Double(calorieString) else { return }
            _ = Entry(calories: calorieDouble)
            do {
                try CoreDataStack.shared.save(context: CoreDataStack.shared.mainContext)
                NotificationCenter.default.post(name: Notification.Name("dataChanged"), object: self)
            } catch {
                print("Error saving entry")
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        self.present(alert, animated: true)

    }

    lazy var fetchedResultsController: NSFetchedResultsController<Entry> = {
        let fetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let moc = CoreDataStack.shared.mainContext
        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: moc, sectionNameKeyPath: "date", cacheName: nil)
        frc.delegate = self
        do {
            try frc.performFetch()
        } catch {
            print("Error fetching entries")
        }
        return frc
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        dateFormatter.dateFormat = "MMM d, h:mm a"
        registerForNotifications()
        NotificationCenter.default.post(name: Notification.Name("dataChanged"), object: self)
    }

    @objc private func updateChart(_ notification: Notification) {
        let data = fetchedResultsController.fetchedObjects?.map { $0.calories}
        self.data = data ?? [0]
        chart.add(series)
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateChart), name: Notification.Name("dataChanged"), object: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EntryCell", for: indexPath)

        cell.textLabel?.text = "Calories: \(String(fetchedResultsController.object(at: indexPath).calories))"
        cell.detailTextLabel?.text = dateFormatter.string(from: fetchedResultsController.object(at: indexPath).date!)
        return cell
    }
}

// MARK: - Extensions

extension EntryTableViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }

    //  swiftlint:disable:next line_length
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .automatic)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .automatic)
        default:
            break
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            guard let newIndexPath = newIndexPath else { return }
            tableView.insertRows(at: [newIndexPath], with: .automatic)
        case .update:
            guard let indexPath = indexPath else { return }
            tableView.reloadRows(at: [indexPath], with: .automatic)
        case .move:
            guard let oldIndexPath = indexPath,
                let newIndexPath = newIndexPath else { return }
            tableView.deleteRows(at: [oldIndexPath], with: .automatic)
            tableView.insertRows(at: [newIndexPath], with: .automatic)
        case .delete:
            guard let indexPath = indexPath else { return }
            tableView.deleteRows(at: [indexPath], with: .automatic)
        @unknown default:
            break
        }
    }
}
